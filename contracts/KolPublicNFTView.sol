// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/BokkyPooBahsDateTimeLibrary.sol";
import "base64-sol/base64.sol";

import "./interfaces/INFTView.sol";
import "./interfaces/IFoundry.sol";
import "./interfaces/IPublicNFT.sol";
import "./interfaces/IKolNFTClaim.sol";

contract KolPublicNFTView is INFTView {
  struct Info {
    string tid;
    string tTwitterName;
    string cid;
    string cTwitterName;
    uint256 followers;
    uint256 omf;
    uint256 percent;
    uint256 timestamp;
    bool isClaim;
  }

  address public immutable foundry;
  uint256 public immutable appId;
  address public immutable publicNFT;
  address public immutable kolNFTClaim;

  constructor(address _foundry, uint256 _appId, address _publicNFT, address _kolNFTClaim) {
    foundry = _foundry;
    appId = _appId;
    publicNFT = _publicNFT;
    kolNFTClaim = _kolNFTClaim;
  }

  function name() external pure override returns (string memory) {
    return "cNFT of KoL Token";
  }

  function symbol() external pure override returns (string memory) {
    return "CNFT_KT";
  }

  function tokenURI(uint256 tokenId) external view override returns (string memory) {
    Info memory info = _getInfo(tokenId);
    string[4] memory styles;

    if (info.percent == 5000) {
      styles = _getCnftStyleStr(info.isClaim);
    } else {
      styles = _getOnftStyleStr(info.isClaim);
    }

    string[19] memory parts;

    parts[
      0
    ] = '<svg width="500" height="500" viewBox="0 0 500 500" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="500" height="500" fill="#1E1E1E"/><path d="M100 0H500V500H100V0Z" fill="#0F4C81"/><rect width="100" height="500" transform="matrix(-1 0 0 1 100 0)" fill="#B2B5BA"/>';
    parts[1] = styles[0];
    parts[2] = "<text ";
    parts[3] = styles[1];

    parts[
      4
    ] = ' xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="40" font-weight="500" letter-spacing="0em"><tspan x="124" y="182.66">@';
    parts[5] = info.tTwitterName;
    parts[
      6
    ] = '</tspan></text><text fill="#B2B5BA" fill-opacity="0.3" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="14" font-weight="500" letter-spacing="0em"><tspan x="124" y="214.306">#';
    parts[7] = info.tid;
    parts[
      8
    ] = '</tspan></text><text fill="#B2B5BA" fill-opacity="0.5" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="16" font-weight="500" letter-spacing="0em"><tspan x="124" y="293.064">Followers</tspan></text><text fill="#B2B5BA" fill-opacity="0.5" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="16" font-weight="500" letter-spacing="0em"><tspan text-anchor="end" x="464" y="293.064">';
    parts[9] = Strings.toString(info.followers);
    parts[
      10
    ] = '</tspan></text><text fill="#B2B5BA" fill-opacity="0.5" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="16" font-weight="500" letter-spacing="0em"><tspan x="124" y="323.064">OMF</tspan></text><text fill="#B2B5BA" fill-opacity="0.5" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="16" font-weight="500" letter-spacing="0em"><tspan text-anchor="end" x="464" y="323.064">';
    parts[11] = string(abi.encodePacked(_getEthStr(info.omf), " E"));
    parts[
      12
    ] = '</tspan></text><text fill="#B2B5BA" fill-opacity="0.5" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="16" font-weight="500" letter-spacing="0em"><tspan text-anchor="end" x="464" y="353.064">';
    parts[13] = _datetime(info.timestamp);
    parts[
      14
    ] = '</tspan></text><text fill="#B2B5BA" fill-opacity="0.7" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="20" font-weight="500" letter-spacing="0em"><tspan text-anchor="end" x="464" y="459.58">KoL Token</tspan></text><text fill="#0F4C81" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="40" font-weight="500" letter-spacing="0em"><tspan ';
    parts[15] = styles[2];
    parts[16] = ">";
    parts[17] = styles[3];
    parts[
      18
    ] = '</tspan></text><text fill="#B2B5BA" fill-opacity="0.7" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="40" font-weight="500" letter-spacing="0em"><tspan x="102" y="461.66">NFT</tspan></text><text fill="#B2B5BA" fill-opacity="0.5" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="16" font-weight="500" letter-spacing="0em"><tspan x="123.453" y="84.064">trading fees distribution right</tspan></text><text fill="#B2B5BA" fill-opacity="0.5" xml:space="preserve" style="white-space: pre" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif" font-size="16" font-weight="500" letter-spacing="0em"><tspan x="103" y="84.064">% </tspan></text><g clip-path="url(#clip0_1_17277)"><path fill-rule="evenodd" clip-rule="evenodd" d="M343.604 443.964C345.05 443.964 346.496 443.964 347.942 443.964C348.22 444.111 348.445 444.325 348.618 444.604C348.665 449.487 348.665 454.37 348.618 459.253C348.479 459.546 348.277 459.783 348.013 459.964C346.567 459.964 345.121 459.964 343.675 459.964C343.396 459.804 343.159 459.59 342.964 459.324C342.964 454.441 342.964 449.559 342.964 444.676C343.125 444.396 343.339 444.159 343.604 443.964Z" fill="#898B90" fill-opacity="0.7"/><path opacity="0.986" fill-rule="evenodd" clip-rule="evenodd" d="M353.631 443.964C354.105 443.964 354.579 443.964 355.053 443.964C356.546 444.367 357.495 445.316 357.898 446.809C357.898 447.283 357.898 447.757 357.898 448.231C357.068 450.649 355.409 451.514 352.92 450.827C351.165 449.912 350.489 448.478 350.893 446.524C351.34 445.164 352.253 444.311 353.631 443.964Z" fill="#FFA400" fill-opacity="0.7"/><path opacity="0.995" fill-rule="evenodd" clip-rule="evenodd" d="M357.898 458.329C357.898 458.756 357.898 459.182 357.898 459.609C357.803 459.751 357.684 459.87 357.542 459.964C355.433 459.964 353.323 459.964 351.213 459.964C351.076 459.863 350.945 459.744 350.822 459.609C350.775 457.476 350.775 455.342 350.822 453.209C350.881 453.055 350.988 452.948 351.142 452.889C353.788 452.831 355.791 453.933 357.151 456.196C357.494 456.882 357.743 457.593 357.898 458.329Z" fill="white" fill-opacity="0.7"/></g><defs><clipPath id="clip0_1_17277"><rect width="14.9333" height="16" fill="white" transform="translate(343 444)"/></clipPath></defs></svg>';
    return _pack(tokenId, parts);
  }

  function _getInfo(uint256 tokenId) private view returns (Info memory info) {
    (info.tid, info.percent, , ) = IPublicNFT(publicNFT).tokenIdToInfo(tokenId);

    bytes memory data = IFoundry(foundry).tokenData(appId, info.tid);
    (info.tTwitterName, info.cid, info.cTwitterName, info.followers, info.omf, info.timestamp) = abi.decode(
      data,
      (string, string, string, uint256, uint256, uint256)
    );
    info.isClaim = IKolNFTClaim(kolNFTClaim).isClaim(info.tid);
  }

  function _getCnftStyleStr(bool isClaim) private pure returns (string[4] memory parts) {
    // percent content
    parts[
      0
    ] = '<path d="M80.0639 85.5966C77.223 85.5966 74.6804 85.0639 72.4361 83.9986C70.1918 82.919 68.4091 81.4418 67.0881 79.5668C65.7813 77.6918 65.0852 75.5469 65 73.1321H72.6705C72.8125 74.9219 73.5866 76.385 74.9929 77.5213C76.3991 78.6435 78.0895 79.2046 80.0639 79.2046C81.6122 79.2046 82.9901 78.8494 84.1974 78.1392C85.4048 77.429 86.3565 76.4418 87.0526 75.1776C87.7486 73.9134 88.0895 72.4716 88.0753 70.8523C88.0895 69.2046 87.7415 67.7415 87.0312 66.4631C86.321 65.1847 85.348 64.1833 84.1122 63.4588C82.8764 62.7202 81.456 62.3509 79.8509 62.3509C78.544 62.3367 77.2585 62.5781 75.9943 63.0753C74.7301 63.5725 73.7287 64.2259 72.9901 65.0355L65.8523 63.8636L68.1321 41.3636H93.4446V47.9688H74.6733L73.4162 59.5384H73.6719C74.4815 58.5867 75.625 57.7983 77.1023 57.1733C78.5795 56.5341 80.1989 56.2145 81.9602 56.2145C84.6023 56.2145 86.9602 56.8395 89.0341 58.0895C91.108 59.3253 92.7415 61.0298 93.9347 63.2031C95.1278 65.3764 95.7244 67.8622 95.7244 70.6605C95.7244 73.544 95.0568 76.1151 93.7216 78.3736C92.4006 80.6179 90.5611 82.3864 88.2031 83.679C85.8594 84.9574 83.1463 85.5966 80.0639 85.5966Z" fill="#0F4C81"/>';
    // tTwitterName style
    if (isClaim) {
      parts[1] = 'fill="#FFA500"';
    } else {
      parts[1] = 'fill="#F2F1F0"';
    }
    // c position
    parts[2] = 'x="75.3867" y="462.16"';
    parts[3] = "c";
  }

  function _getOnftStyleStr(bool isClaim) private pure returns (string[4] memory parts) {
    // percent content
    parts[
      0
    ] = '<path d="M41.4494 40.767C43.5374 40.7812 45.5687 41.1506 47.5431 41.875C49.5317 42.5852 51.3215 43.75 52.9124 45.3693C54.5033 46.9744 55.7675 49.1264 56.705 51.8253C57.6425 54.5241 58.1113 57.8622 58.1113 61.8395C58.1255 65.5895 57.7278 68.9418 56.9181 71.8963C56.1226 74.8366 54.9792 77.3224 53.4877 79.3537C51.9962 81.3849 50.1994 82.9332 48.0971 83.9986C45.9948 85.0639 43.6298 85.5966 41.0019 85.5966C38.2462 85.5966 35.803 85.0568 33.6724 83.9773C31.5559 82.8977 29.8442 81.4205 28.5374 79.5455C27.2306 77.6705 26.428 75.5256 26.1297 73.1108H33.9067C34.3045 74.8437 35.1141 76.2216 36.3357 77.2443C37.5715 78.2528 39.1269 78.7571 41.0019 78.7571C44.0275 78.7571 46.357 77.4432 47.9905 74.8153C49.6241 72.1875 50.4408 68.5369 50.4408 63.8636H50.1425C49.4465 65.1136 48.5445 66.1932 47.4366 67.1023C46.3286 67.9972 45.0715 68.6861 43.6653 69.169C42.2732 69.652 40.7959 69.8935 39.2334 69.8935C36.6766 69.8935 34.3755 69.2827 32.33 68.0611C30.2988 66.8395 28.6866 65.1633 27.4934 63.0327C26.3144 60.902 25.7178 58.4659 25.7036 55.7244C25.7036 52.8835 26.357 50.3338 27.6638 48.0753C28.9849 45.8026 30.8244 44.0128 33.1823 42.706C35.5403 41.3849 38.2959 40.7386 41.4494 40.767ZM41.4707 47.1591C39.9366 47.1591 38.5516 47.5355 37.3158 48.2883C36.0942 49.027 35.1283 50.0355 34.4181 51.3139C33.7221 52.5781 33.3741 53.9915 33.3741 55.554C33.3883 57.1023 33.7363 58.5085 34.4181 59.7727C35.1141 61.0369 36.0587 62.0383 37.2519 62.777C38.4593 63.5156 39.8371 63.8849 41.3854 63.8849C42.536 63.8849 43.6084 63.6648 44.6028 63.2244C45.5971 62.7841 46.4636 62.1733 47.2022 61.392C47.955 60.5966 48.5374 59.6946 48.9494 58.6861C49.3755 57.6776 49.5815 56.6122 49.5672 55.4901C49.5672 53.9986 49.2121 52.6207 48.5019 51.3565C47.8059 50.0923 46.8471 49.0767 45.6255 48.3097C44.4181 47.5426 43.0332 47.1591 41.4707 47.1591Z" fill="#8A8C91"/><path d="M79.6569 85.5966C76.816 85.5966 74.2734 85.0639 72.0291 83.9986C69.7847 82.919 68.0021 81.4418 66.6811 79.5668C65.3742 77.6918 64.6782 75.5469 64.593 73.1321H72.2634C72.4055 74.9219 73.1796 76.3849 74.5859 77.5213C75.9921 78.6435 77.6825 79.2045 79.6569 79.2045C81.2052 79.2045 82.583 78.8494 83.7904 78.1392C84.9978 77.429 85.9495 76.4418 86.6455 75.1776C87.3416 73.9133 87.6825 72.4716 87.6683 70.8523C87.6825 69.2045 87.3345 67.7415 86.6242 66.4631C85.914 65.1847 84.941 64.1832 83.7052 63.4588C82.4694 62.7202 81.049 62.3508 79.4438 62.3508C78.137 62.3366 76.8515 62.5781 75.5873 63.0753C74.3231 63.5724 73.3217 64.2258 72.583 65.0355L65.4453 63.8636L67.7251 41.3636H93.0376V47.9687H74.2663L73.0092 59.5383H73.2649C74.0745 58.5866 75.218 57.7983 76.6953 57.1733C78.1725 56.5341 79.7919 56.2145 81.5532 56.2145C84.1953 56.2145 86.5532 56.8395 88.6271 58.0895C90.7009 59.3253 92.3345 61.0298 93.5276 63.2031C94.7208 65.3764 95.3174 67.8622 95.3174 70.6605C95.3174 73.544 94.6498 76.1151 93.3146 78.3736C91.9936 80.6179 90.1541 82.3864 87.7961 83.679C85.4524 84.9574 82.7393 85.5966 79.6569 85.5966Z" fill="#8A8C91"/>';
    // tTwitterName style
    if (isClaim) {
      parts[1] = 'fill="#FFA500"';
    } else {
      parts[1] = 'fill="#F2F1F0"';
    }
    // o position
    parts[2] = 'x="74.6445" y="462.16"';
    parts[3] = "o";
  }

  function _getEthStr(uint256 eth) private pure returns (string memory) {
    uint256 integer = eth / (10 ** 18);
    uint256 decimal = eth / (10 ** 15) - integer * 1000;
    return string(abi.encodePacked(Strings.toString(integer), ".", Strings.toString(decimal)));
  }

  function _datetime(uint256 timestamp) private pure returns (string memory date) {
    (uint256 year, uint256 month, uint256 day) = BokkyPooBahsDateTimeLibrary.timestampToDate(timestamp);
    string memory yearStr = Strings.toString(year);
    string memory monthStr = Strings.toString(month);
    string memory dayStr = Strings.toString(day);
    if (bytes(dayStr).length == 1) {
      dayStr = string(abi.encodePacked("0", dayStr));
    }
    if (bytes(monthStr).length == 1) {
      monthStr = string(abi.encodePacked("0", monthStr));
    }
    date = string(abi.encodePacked(monthStr, "/", dayStr, "/", yearStr));
  }

  function _pack(uint256 tokenId, string[19] memory parts) private view returns (string memory output) {
    string memory partsOutput = string(
      abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6])
    );

    partsOutput = string(abi.encodePacked(partsOutput, parts[7], parts[8], parts[9], parts[10], parts[11], parts[12]));

    partsOutput = string(
      abi.encodePacked(partsOutput, parts[13], parts[14], parts[15], parts[16], parts[17], parts[18])
    );

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "',
            _name(tokenId),
            '", "description": "',
            _desc(tokenId),
            '", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(partsOutput)),
            '"}'
          )
        )
      )
    );
    output = string(abi.encodePacked("data:application/json;base64,", json));
  }

  function _name(uint256 tokenId) private view returns (string memory) {
    Info memory info = _getInfo(tokenId);
    string memory _type = "";
    if (info.percent == 5000) {
      _type = "cNFT";
    } else {
      _type = "oNFT";
    }
    return string(abi.encodePacked("@", info.tTwitterName, " - ", _type));
  }

  function _desc(uint256 tokenId) private view returns (string memory) {
    Info memory info = _getInfo(tokenId);
    if (info.percent == 5000) {
      return
        string(
          abi.encodePacked(
            "This NFT entitles the holder the right to perpetually collect 5% trading fees from @",
            info.tTwitterName,
            unicode"’s KT trades on the KoL Token platform."
          )
        );
    } else {
      return
        string(
          abi.encodePacked(
            "This NFT entitles the holder the right to perpetually collect 95% trading fees from @",
            info.tTwitterName,
            unicode"’s KT trades on the KoL Token platform."
          )
        );
    }
  }
}
