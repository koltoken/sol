// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import "./interfaces/IPublicNFT.sol";
import "./interfaces/IMortgageNFT.sol";
import "./interfaces/IMarket.sol";
import "./interfaces/IFoundry.sol";
import "./interfaces/ICurve.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Market is IMarket, ReentrancyGuard {
  uint256 public immutable override feeDenominator;
  uint256 public immutable override totalPercent;

  address public immutable override foundry;
  uint256 public immutable override appId;

  address public immutable override curve;
  uint256 public immutable override buySellFee;

  address public override publicNFT;
  address public override mortgageNFT;

  // tid => totalSupply
  mapping(string => uint256) private _totalSupply;

  // tid => account => amount
  mapping(string => mapping(address => uint256)) private _balanceOf;

  constructor(
    address _foundry,
    uint256 _appId,
    uint256 _feeDenominator,
    uint256 _totalPercent,
    address _curve,
    uint256 _buySellFee
  ) {
    foundry = _foundry;
    appId = _appId;

    feeDenominator = _feeDenominator;
    totalPercent = _totalPercent;

    curve = _curve;
    buySellFee = _buySellFee;
  }

  function initialize(address _publicNFT, address _mortgageNFT) external override {
    require(msg.sender == foundry, "onlyFoundry");

    publicNFT = _publicNFT;
    mortgageNFT = _mortgageNFT;

    emit Initialize(_publicNFT, _mortgageNFT);
  }

  function totalSupply(string memory tid) external view override returns (uint256) {
    return _totalSupply[tid];
  }

  function balanceOf(string memory tid, address account) external view override returns (uint256) {
    return _balanceOf[tid][account];
  }

  function getBuyETHAmount(string memory tid, uint256 tokenAmount) public view override returns (uint256 ethAmount) {
    uint256 ts = _totalSupply[tid];
    return getETHAmount(ts, tokenAmount);
  }

  function getSellETHAmount(string memory tid, uint256 tokenAmount) public view override returns (uint256 ethAmount) {
    uint256 ts = _totalSupply[tid];
    return getETHAmount(ts - tokenAmount, tokenAmount);
  }

  function getETHAmount(uint256 base, uint256 add) public view override returns (uint256 ethAmount) {
    return ICurve(curve).curveMath(base, add);
  }

  function buy(
    string memory tid,
    uint256 tokenAmount
  ) external payable override nonReentrant returns (uint256 ethAmount) {
    require(IFoundry(foundry).tokenExist(appId, tid), "TE");

    require(tokenAmount > 0, "TAE");

    uint256[] memory feeTokenIds;
    address[] memory feeTos;
    uint256[] memory feeAmounts;

    (ethAmount, feeTokenIds, feeTos, feeAmounts) = _buyWithoutTransferEth(msg.sender, tid, tokenAmount);

    require(msg.value >= ethAmount, "VE");
    _batchTransferEthToNFTOwners(feeTokenIds, feeTos, feeAmounts);
    _refundETH(ethAmount);

    emit Buy(tid, tokenAmount, ethAmount, msg.sender, feeTokenIds, feeTos, feeAmounts);
  }

  function sell(string memory tid, uint256 tokenAmount) external override nonReentrant returns (uint256 ethAmount) {
    require(IFoundry(foundry).tokenExist(appId, tid), "TE");

    require(tokenAmount > 0, "TAE");
    require(tokenAmount <= _balanceOf[tid][msg.sender], "TAE");

    uint256[] memory feeTokenIds;
    address[] memory feeTos;
    uint256[] memory feeAmounts;

    (ethAmount, feeTokenIds, feeTos, feeAmounts) = _sellWithoutTransferEth(msg.sender, tid, tokenAmount);

    _transferEth(msg.sender, ethAmount);
    _batchTransferEthToNFTOwners(feeTokenIds, feeTos, feeAmounts);

    emit Sell(tid, tokenAmount, ethAmount, msg.sender, feeTokenIds, feeTos, feeAmounts);
  }

  function mortgage(
    string memory tid,
    uint256 tokenAmount
  ) external override nonReentrant returns (uint256 nftTokenId, uint256 ethAmount) {
    require(IFoundry(foundry).tokenExist(appId, tid), "TE");
    require(tokenAmount > 0, "TAE");
    require(tokenAmount <= _balanceOf[tid][msg.sender], "TAE");

    nftTokenId = IMortgageNFT(mortgageNFT).mint(msg.sender, tid, tokenAmount);

    ethAmount = _mortgageAdd(nftTokenId, tid, 0, tokenAmount);
  }

  function mortgageAdd(
    uint256 nftTokenId,
    uint256 tokenAmount
  ) external override nonReentrant returns (uint256 ethAmount) {
    require(IMortgageNFT(mortgageNFT).isApprovedOrOwner(msg.sender, nftTokenId), "AOE");

    (string memory tid, uint256 oldAmount) = IMortgageNFT(mortgageNFT).info(nftTokenId);
    require(tokenAmount > 0, "TAE");
    require(tokenAmount <= _balanceOf[tid][msg.sender], "TAE");

    IMortgageNFT(mortgageNFT).add(nftTokenId, tokenAmount);

    ethAmount = _mortgageAdd(nftTokenId, tid, oldAmount, tokenAmount);
  }

  function redeem(
    uint256 nftTokenId,
    uint256 tokenAmount
  ) external payable override nonReentrant returns (uint256 ethAmount) {
    require(IMortgageNFT(mortgageNFT).isApprovedOrOwner(msg.sender, nftTokenId), "AOE");

    (string memory tid, uint256 oldAmount) = IMortgageNFT(mortgageNFT).info(nftTokenId);
    require(tokenAmount > 0, "TAE");
    require(tokenAmount <= oldAmount, "TAE");

    IMortgageNFT(mortgageNFT).remove(nftTokenId, tokenAmount);

    ethAmount = getETHAmount(oldAmount - tokenAmount, tokenAmount);
    require(msg.value >= ethAmount, "VE");

    _balanceOf[tid][address(this)] -= tokenAmount;
    _balanceOf[tid][msg.sender] += tokenAmount;

    _refundETH(ethAmount);

    emit Redeem(nftTokenId, tid, tokenAmount, ethAmount, msg.sender);
  }

  function multiply(
    string memory tid,
    uint256 multiplyAmount
  ) external payable override nonReentrant returns (uint256 nftTokenId, uint256 ethAmount) {
    require(IFoundry(foundry).tokenExist(appId, tid), "TE");
    require(multiplyAmount > 0, "TAE");

    nftTokenId = IMortgageNFT(mortgageNFT).mint(msg.sender, tid, multiplyAmount);

    ethAmount = _multiplyAdd(nftTokenId, tid, 0, multiplyAmount);
  }

  function multiplyAdd(
    uint256 nftTokenId,
    uint256 multiplyAmount
  ) external payable override nonReentrant returns (uint256 ethAmount) {
    require(IMortgageNFT(mortgageNFT).isApprovedOrOwner(msg.sender, nftTokenId), "AOE");
    require(multiplyAmount > 0, "TAE");

    (string memory tid, uint256 oldAmount) = IMortgageNFT(mortgageNFT).info(nftTokenId);
    IMortgageNFT(mortgageNFT).add(nftTokenId, multiplyAmount);

    ethAmount = _multiplyAdd(nftTokenId, tid, oldAmount, multiplyAmount);
  }

  function cash(uint256 nftTokenId, uint256 tokenAmount) external override nonReentrant returns (uint256 ethAmount) {
    require(IMortgageNFT(mortgageNFT).isApprovedOrOwner(msg.sender, nftTokenId), "AOE");

    (string memory tid, uint256 oldAmount) = IMortgageNFT(mortgageNFT).info(nftTokenId);
    require(tokenAmount > 0, "TAE");
    require(tokenAmount <= oldAmount, "TAE");

    IMortgageNFT(mortgageNFT).remove(nftTokenId, tokenAmount);

    (
      uint256 sellAmount,
      uint256[] memory feeTokenIds,
      address[] memory feeTos,
      uint256[] memory feeAmounts
    ) = _sellWithoutTransferEth(address(this), tid, tokenAmount);

    uint256 redeemEth = getETHAmount(oldAmount - tokenAmount, tokenAmount);

    require(sellAmount >= redeemEth, "CE");
    ethAmount = sellAmount - redeemEth;

    if (ethAmount > 0) {
      _transferEth(msg.sender, ethAmount);
    }

    _batchTransferEthToNFTOwners(feeTokenIds, feeTos, feeAmounts);

    emit Cash(nftTokenId, tid, tokenAmount, ethAmount, msg.sender, feeTokenIds, feeTos, feeAmounts);
  }

  function merge(
    uint256 nftTokenId,
    uint256 otherNFTTokenId
  ) external override nonReentrant returns (uint256 ethAmount) {
    require(IMortgageNFT(mortgageNFT).isApprovedOrOwner(msg.sender, nftTokenId), "AOE1");
    require(IMortgageNFT(mortgageNFT).isApprovedOrOwner(msg.sender, otherNFTTokenId), "AOE2");

    (string memory tid, uint256 oldAmount) = IMortgageNFT(mortgageNFT).info(nftTokenId);
    (string memory otherTid, uint256 otherOldAmount) = IMortgageNFT(mortgageNFT).info(otherNFTTokenId);

    require(keccak256(abi.encodePacked(tid)) == keccak256(abi.encodePacked(otherTid)), "TE");

    IMortgageNFT(mortgageNFT).burn(otherNFTTokenId);
    IMortgageNFT(mortgageNFT).add(nftTokenId, otherOldAmount);

    uint256 eth = getETHAmount(oldAmount, otherOldAmount) - getETHAmount(0, otherOldAmount);
    uint256 feeAmount = _mortgageFee(eth);
    ethAmount = eth - feeAmount;

    _transferEth(msg.sender, ethAmount);
    _transferEthToMortgageFeeRecipient(feeAmount);

    emit Merge(nftTokenId, tid, otherNFTTokenId, ethAmount, feeAmount, msg.sender);
  }

  function split(
    uint256 nftTokenId,
    uint256 splitAmount
  ) external payable override nonReentrant returns (uint256 ethAmount, uint256 newNFTTokenId) {
    require(IMortgageNFT(mortgageNFT).isApprovedOrOwner(msg.sender, nftTokenId), "AOE");

    (string memory tid, uint256 oldAmount) = IMortgageNFT(mortgageNFT).info(nftTokenId);
    require(splitAmount > 0, "SAE");
    require(splitAmount < oldAmount, "SAE");

    IMortgageNFT(mortgageNFT).remove(nftTokenId, splitAmount);
    newNFTTokenId = IMortgageNFT(mortgageNFT).mint(msg.sender, tid, splitAmount);

    ethAmount = getETHAmount(oldAmount - splitAmount, splitAmount) - getETHAmount(0, splitAmount);

    require(msg.value >= ethAmount, "VE");

    _refundETH(ethAmount);

    emit Split(nftTokenId, newNFTTokenId, tid, splitAmount, ethAmount, msg.sender);
  }

  function _buyWithoutTransferEth(
    address to,
    string memory tid,
    uint256 tokenAmount
  )
    private
    returns (uint256 ethAmount, uint256[] memory feeTokenIds, address[] memory feeTos, uint256[] memory feeAmounts)
  {
    uint256 eth = getBuyETHAmount(tid, tokenAmount);

    uint256 totalFee;
    (totalFee, feeTokenIds, feeTos, feeAmounts) = _getFee(tid, eth);
    ethAmount = eth + totalFee;

    _totalSupply[tid] += tokenAmount;
    _balanceOf[tid][to] += tokenAmount;
  }

  function _sellWithoutTransferEth(
    address from,
    string memory tid,
    uint256 tokenAmount
  )
    private
    returns (uint256 ethAmount, uint256[] memory feeTokenIds, address[] memory feeTos, uint256[] memory feeAmounts)
  {
    uint256 eth = getSellETHAmount(tid, tokenAmount);

    uint256 totalFee;
    (totalFee, feeTokenIds, feeTos, feeAmounts) = _getFee(tid, eth);
    ethAmount = eth - totalFee;

    _totalSupply[tid] -= tokenAmount;
    _balanceOf[tid][from] -= tokenAmount;
  }

  function _mortgageAdd(
    uint256 tokenId,
    string memory tid,
    uint256 oldAmount,
    uint256 addAmount
  ) private returns (uint256 ethAmount) {
    uint256 eth = getETHAmount(oldAmount, addAmount);
    uint256 feeAmount = _mortgageFee(eth);

    _balanceOf[tid][msg.sender] -= addAmount;
    _balanceOf[tid][address(this)] += addAmount;

    ethAmount = eth - feeAmount;
    _transferEth(msg.sender, ethAmount);
    _transferEthToMortgageFeeRecipient(feeAmount);

    emit Mortgage(tokenId, tid, addAmount, ethAmount, feeAmount, msg.sender);
  }

  function _multiplyAdd(
    uint256 nftTokenId,
    string memory tid,
    uint256 oldAmount,
    uint256 multiplyAmount
  ) private returns (uint256 ethAmount) {
    (
      uint256 ethMultiplyAmount,
      uint256[] memory feeTokenIds,
      address[] memory feeTos,
      uint256[] memory feeAmounts
    ) = _buyWithoutTransferEth(address(this), tid, multiplyAmount);

    uint256 eth = getETHAmount(oldAmount, multiplyAmount);
    uint256 feeAmount = _mortgageFee(eth);
    uint256 ethMortAmount = eth - feeAmount;
    ethAmount = ethMultiplyAmount - ethMortAmount;

    require(msg.value >= ethAmount, "VE");

    _transferEthToMortgageFeeRecipient(feeAmount);
    _batchTransferEthToNFTOwners(feeTokenIds, feeTos, feeAmounts);
    _refundETH(ethAmount);

    emit Multiply(nftTokenId, tid, multiplyAmount, ethAmount, feeAmount, msg.sender, feeTokenIds, feeTos, feeAmounts);
  }

  function _getFee(
    string memory tid,
    uint256 eth
  )
    private
    view
    returns (uint256 totalFee, uint256[] memory tokenIds, address[] memory owners, uint256[] memory percentEths)
  {
    uint256[] memory percents;
    (tokenIds, percents, , owners) = IPublicNFT(publicNFT).tidToInfos(tid);

    percentEths = new uint256[](percents.length);

    for (uint256 i = 0; i < percents.length; i++) {
      uint256 feeAmount = (eth * buySellFee * percents[i]) / totalPercent / feeDenominator;
      percentEths[i] = feeAmount;
      totalFee += feeAmount;
    }
  }

  function _batchTransferEthToNFTOwners(
    uint256[] memory tokenIds,
    address[] memory tos,
    uint256[] memory amounts
  ) private {
    for (uint256 i = 0; i < amounts.length; i++) {
      if (tos[i].code.length > 0) {
        _transferEthWithData(tokenIds[i], tos[i], amounts[i]);
      } else {
        _transferEth(tos[i], amounts[i]);
      }
    }
  }

  function _transferEthToMortgageFeeRecipient(uint256 feeAmount) private {
    _transferEth(IFoundry(foundry).mortgageFeeRecipient(appId), feeAmount);
  }

  function _refundETH(uint256 needPay) private {
    uint256 refund = msg.value - needPay;
    if (refund > 0) {
      _transferEth(msg.sender, refund);
    }
  }

  function _transferEth(address to, uint256 value) private {
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, "TEE");
  }

  function _transferEthWithData(uint256 tokenId, address to, uint256 value) private {
    (bool success, ) = to.call{value: value}(abi.encode("buySellFee", tokenId));
    require(success, "TEE");
  }

  function _mortgageFee(uint256 _eth) private view returns (uint256) {
    return (IFoundry(foundry).mortgageFee(appId) * _eth) / feeDenominator;
  }
}
