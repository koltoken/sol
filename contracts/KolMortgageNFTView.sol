// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

import "./interfaces/INFTView.sol";
import "./interfaces/IFoundry.sol";
import "./interfaces/IMortgageNFT.sol";
import "./interfaces/IKolNFTClaim.sol";

contract KolMortgageNFTView is INFTView {
  struct Info {
    string tid;
    string tTwitterName;
    string cid;
    string cTwitterName;
    uint256 followers;
    uint256 omf;
    uint256 timestamp;
    bool isClaim;
    uint256 amount;
  }

  address public immutable foundry;
  uint256 public immutable appId;
  address public immutable mortgageNFT;
  address public immutable kolNFTClaim;

  constructor(address _foundry, uint256 _appId, address _mortgageNFT, address _kolNFTClaim) {
    foundry = _foundry;
    appId = _appId;
    mortgageNFT = _mortgageNFT;
    kolNFTClaim = _kolNFTClaim;
  }

  function name() external pure override returns (string memory) {
    return "KoL Position";
  }

  function symbol() external pure override returns (string memory) {
    return "KOLP";
  }

  function tokenURI(uint256 tokenId) external view override returns (string memory) {
    Info memory info = _getInfo(tokenId);
    string[7] memory parts;

    parts[
      0
    ] = '<svg width="290" height="290" viewBox="0 0 290 290" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="290" height="290" rx="42" fill="#2B2F3A"/><text fill="#B2B5BA" fill-opacity="0.3" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="14" font-weight="500" letter-spacing="0em"><tspan x="40" y="68.306">#';
    parts[1] = info.tid;
    parts[
      2
    ] = '</tspan></text><text fill="white" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="24" font-weight="500" letter-spacing="0em"><tspan x="40" y="97.596">@';
    parts[3] = info.tTwitterName;
    parts[
      4
    ] = '</tspan></text><text fill="white" fill-opacity="0.65" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="14" letter-spacing="0em"><tspan x="40" y="188.673">Collateral Locked</tspan></text><text fill="white" fill-opacity="0.85" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="32" font-weight="500" letter-spacing="0em"><tspan x="40" y="223.628">';
    parts[5] = _getShowAmount(info.amount);
    parts[6] = "</tspan></text></svg>";

    string memory partsOutput = string(
      abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6])
    );

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "',
            _name(tokenId),
            '", "description": "',
            _desc(),
            '", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(partsOutput)),
            '"}'
          )
        )
      )
    );
    return string(abi.encodePacked("data:application/json;base64,", json));
  }

  function _getShowAmount(uint256 amount) private pure returns (string memory) {
    uint256 _int = amount / (10 ** 18);
    uint256 _dec = amount / (10 ** 16) - _int * 100;
    uint256 _dec1 = _dec / 10;
    uint256 _dec2 = _dec - _dec1 * 10;

    if (_dec1 == 0 && _dec2 == 0) {
      return Strings.toString(_int);
    }

    if (_dec1 != 0 && _dec2 == 0) {
      return string(abi.encodePacked(Strings.toString(_int), ".", Strings.toString(_dec1)));
    }

    return string(abi.encodePacked(Strings.toString(_int), ".", Strings.toString(_dec1), Strings.toString(_dec2)));
  }

  function _getInfo(uint256 tokenId) private view returns (Info memory info) {
    (info.tid, info.amount) = IMortgageNFT(mortgageNFT).info(tokenId);
    bytes memory data = IFoundry(foundry).tokenData(appId, info.tid);
    (info.tTwitterName, info.cid, info.cTwitterName, info.followers, info.omf, info.timestamp) = abi.decode(
      data,
      (string, string, string, uint256, uint256, uint256)
    );
    info.isClaim = IKolNFTClaim(kolNFTClaim).isClaim(info.tid);
  }

  function _name(uint256 tokenId) private view returns (string memory) {
    Info memory info = _getInfo(tokenId);
    return
      string(
        abi.encodePacked("@", info.tTwitterName, " - #", Strings.toString(tokenId), " - ", _getShowAmount(info.amount))
      );
  }

  function _desc() private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          "This NFT represents a collateral position within the KoL Token system.\\n",
          unicode"⚠️ DISCLAIMER: Due diligence is imperative when assessing this NFT. Make sure that the NFT image matches the number of KT in the collateral position. As NFT trading platforms cache images, it's advised to refresh the cached image for the latest data before purchasing the NFT."
        )
      );
  }
}
