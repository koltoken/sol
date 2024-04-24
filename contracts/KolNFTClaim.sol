// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./interfaces/IPublicNFT.sol";
import "./interfaces/IKolNFTClaim.sol";

contract KolNFTClaim is IKolNFTClaim, Ownable, ERC721Holder {
  using ECDSA for bytes32;

  address public immutable kol;
  address public immutable publicNFT;
  address public signatureAddress;
  // tid => claim
  mapping(string => bool) public override isClaim;
  // tokenid => amount
  mapping(uint256 => uint256) public ethAmount;

  event SetSignatureAddress(address _signatureAddress, address sender);
  event ClaimNFT(string tid, uint256 tokenId, address nftOwner, uint256 ethAmount, address sender);
  event Withdraw(string tid, uint256 tokenId, uint256 amount, address sender);
  event ReceiveBuySellFee(uint256 tokenId, uint256 amount);

  constructor(address _kol, address _publicNFT, address _signatureAddress) Ownable() {
    kol = _kol;
    publicNFT = _publicNFT;
    signatureAddress = _signatureAddress;
  }

  function setSignatureAddress(address _signatureAddress) external onlyOwner {
    signatureAddress = _signatureAddress;

    emit SetSignatureAddress(_signatureAddress, msg.sender);
  }

  function setClaim(string memory tid) external override {
    require(msg.sender == kol, "SE");

    isClaim[tid] = true;
    emit SetClaim(tid);
  }

  function claimNFT(string memory tid, address nftOwner, bytes memory signature) external {
    require(!isClaim[tid], "CE");

    _verifyClaimSignature(tid, nftOwner, signature);
    isClaim[tid] = true;

    uint256 tokenId = _findTokenIdByTid(tid);

    IERC721(publicNFT).safeTransferFrom(address(this), nftOwner, tokenId);

    uint256 eth = ethAmount[tokenId];
    ethAmount[tokenId] = 0;

    _transferEth(nftOwner, eth);

    emit ClaimNFT(tid, tokenId, nftOwner, eth, msg.sender);
  }

  function withdraw(string memory tid, uint256 amount) external onlyOwner {
    uint256 tokenId = _findTokenIdByTid(tid);
    require(ethAmount[tokenId] >= amount, "EAE");

    ethAmount[tokenId] -= amount;

    _transferEth(owner(), amount);

    emit Withdraw(tid, tokenId, amount, msg.sender);
  }

  // abi.encode("buySellFee", tokenId)
  function decodeData(bytes memory data) external pure returns (string memory name, uint256 tokenId) {
    (name, tokenId) = abi.decode(data, (string, uint256));
  }

  function _findTokenIdByTid(string memory tid) private view returns (uint256 tokenId) {
    (uint256[] memory tokenIds, uint256[] memory percents, , ) = IPublicNFT(publicNFT).tidToInfos(tid);
    require(tokenIds.length == 2, "TE1");

    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (percents[i] == 95000) {
        tokenId = tokenIds[i];
        break;
      }
    }

    require(tokenId != 0, "TE2");
  }

  function _transferEth(address to, uint256 value) private {
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, "TEE");
  }

  function _verifyClaimSignature(string memory tid, address nftOwner, bytes memory signature) private view {
    bytes32 raw = keccak256(abi.encode(tid, nftOwner));

    require(raw.toEthSignedMessageHash().recover(signature) == signatureAddress, "VSE");
  }

  fallback() external payable {
    try this.decodeData(msg.data) returns (string memory name, uint256 tokenId) {
      if (keccak256(bytes(name)) == keccak256(bytes("buySellFee"))) {
        ethAmount[tokenId] += msg.value;

        emit ReceiveBuySellFee(tokenId, msg.value);
      }
    } catch {}
  }

  receive() external payable {}
}
