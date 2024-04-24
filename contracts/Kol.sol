// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./interfaces/IMarket.sol";
import "./interfaces/IFoundry.sol";
import "./interfaces/IKolNFTClaim.sol";

contract Kol is Ownable, ERC721Holder {
  using ECDSA for bytes32;

  struct TokenInfo {
    string tid;
    string tTwitterName;
    string cid;
    string cTwitterName;
    uint256 followers;
    uint256 omf;
  }

  address public immutable foundry;
  uint256 public immutable appId;
  address public immutable mortgageNFT;
  address public immutable market;
  address public immutable kolNFTClaim;
  address public fundRecipient;
  address public signatureAddress;

  event CreateToken(
    TokenInfo info,
    uint256 cNFTTokenId,
    uint256 oNFTTokenId,
    uint256 nftPrice,
    uint256 deadline,
    address sender
  );
  event CreateTokenAndMultiply(
    TokenInfo info,
    uint256 cNFTTokenId,
    uint256 oNFTTokenId,
    uint256 nftPrice,
    uint256 deadline,
    uint256 multiplyAmount,
    uint256 tokenId,
    uint256 ethAmount,
    address sender
  );

  event SetFundRecipient(address _fundRecipient, address sender);
  event SetSignatureAddress(address _signatureAddress, address sender);

  modifier checkTimestamp(uint256 deadline) {
    require(block.timestamp <= deadline, "CTE");
    _;
  }

  constructor(
    address _foundry,
    uint256 _appId,
    address _mortgageNFT,
    address _market,
    address _kolNFTClaim,
    address _fundRecipient,
    address _signatureAddress
  ) Ownable() {
    foundry = _foundry;
    appId = _appId;
    mortgageNFT = _mortgageNFT;
    market = _market;

    kolNFTClaim = _kolNFTClaim;
    fundRecipient = _fundRecipient;
    signatureAddress = _signatureAddress;
  }

  function createToken(
    TokenInfo memory info,
    uint256 nftPrice,
    uint256 deadline,
    bytes memory signature
  ) external payable checkTimestamp(deadline) {
    require(msg.value >= nftPrice, "PE");

    uint256[] memory nftTokenIds = _createTokenWithoutPay(info, nftPrice, deadline, signature);

    if (nftPrice > 0) {
      _transferEth(fundRecipient, nftPrice);
    }
    _refundETH(nftPrice);

    emit CreateToken(info, nftTokenIds[0], nftTokenIds[1], nftPrice, deadline, msg.sender);
  }

  function createTokenAndMultiply(
    TokenInfo memory info,
    uint256 nftPrice,
    uint256 deadline,
    bytes memory signature,
    uint256 multiplyAmount
  ) external payable checkTimestamp(deadline) returns (uint256 ethAmount) {
    uint256[] memory nftTokenIds = _createTokenWithoutPay(info, nftPrice, deadline, signature);

    uint256 tokenId;
    (tokenId, ethAmount) = IMarket(market).multiply{value: msg.value - nftPrice}(info.tid, multiplyAmount);

    ethAmount = nftPrice + ethAmount;
    require(msg.value >= ethAmount, "PE");

    IERC721(mortgageNFT).safeTransferFrom(address(this), _msgSender(), tokenId);

    if (nftPrice > 0) {
      _transferEth(fundRecipient, nftPrice);
    }
    _refundETH(ethAmount);

    emit CreateTokenAndMultiply(
      info,
      nftTokenIds[0],
      nftTokenIds[1],
      nftPrice,
      deadline,
      multiplyAmount,
      tokenId,
      ethAmount,
      msg.sender
    );
  }

  function setFundRecipient(address _fundRecipient) external onlyOwner {
    fundRecipient = _fundRecipient;

    emit SetFundRecipient(_fundRecipient, msg.sender);
  }

  function setSignatureAddress(address _signatureAddress) external onlyOwner {
    signatureAddress = _signatureAddress;

    emit SetSignatureAddress(_signatureAddress, msg.sender);
  }

  function _createTokenWithoutPay(
    TokenInfo memory info,
    uint256 nftPrice,
    uint256 deadline,
    bytes memory signature
  ) private returns (uint256[] memory nftTokenIds) {
    _verifySignature(info, nftPrice, deadline, signature);

    address oNFTOwner;
    if (keccak256(abi.encodePacked(info.tid)) == keccak256(abi.encodePacked(info.cid))) {
      oNFTOwner = _msgSender();
    } else {
      oNFTOwner = kolNFTClaim;
    }

    nftTokenIds = IFoundry(foundry).createToken(
      appId,
      info.tid,
      _encodeTdata(info.tTwitterName, info.cid, info.cTwitterName, info.followers, info.omf),
      _nftPercents(),
      _nftOwners(_msgSender(), oNFTOwner),
      new bytes[](2)
    );

    if (_msgSender() == oNFTOwner) {
      IKolNFTClaim(kolNFTClaim).setClaim(info.tid);
    }
  }

  function _nftPercents() private pure returns (uint256[] memory) {
    uint256[] memory result = new uint256[](2);
    result[0] = 5000;
    result[1] = 95000;
    return result;
  }

  function _nftOwners(address cOwner, address oOwner) private pure returns (address[] memory) {
    address[] memory result = new address[](2);
    result[0] = cOwner;
    result[1] = oOwner;
    return result;
  }

  function _encodeTdata(
    string memory tTwitterName,
    string memory cid,
    string memory cTwitterName,
    uint256 followers,
    uint256 omf
  ) private view returns (bytes memory) {
    return abi.encode(tTwitterName, cid, cTwitterName, followers, omf, block.timestamp);
  }

  function _verifySignature(
    TokenInfo memory info,
    uint256 nftPrice,
    uint256 deadline,
    bytes memory signature
  ) private view {
    bytes32 raw = keccak256(abi.encode(info, nftPrice, deadline, _msgSender()));
    require(raw.toEthSignedMessageHash().recover(signature) == signatureAddress, "VSE");
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

  receive() external payable {}
}
