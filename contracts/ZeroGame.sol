pragma solidity ^0.4.18;

import "./ERC721.sol";

contract ZeroToken is ERC721 {
  /*** CONSTANTS ***/

  string public constant name = "ZeroToken";
  string public constant symbol = "ZERO";

  bytes4 constant InterfaceID_ERC165 =
    bytes4(keccak256('supportsInterface(bytes4)'));

  bytes4 constant InterfaceID_ERC721 =
    bytes4(keccak256('name()')) ^
    bytes4(keccak256('symbol()')) ^
    bytes4(keccak256('totalSupply()')) ^
    bytes4(keccak256('balanceOf(address)')) ^
    bytes4(keccak256('ownerOf(uint256)')) ^
    bytes4(keccak256('approve(address,uint256)')) ^
    bytes4(keccak256('transfer(address,uint256)')) ^
    bytes4(keccak256('transferFrom(address,address,uint256)')) ^
    bytes4(keccak256('tokensOfOwner(address)'));


  /*** DATA TYPES ***/

  struct Token {
    address mintedBy;
    uint64 createTime;
    uint64 openTime;
    uint32 limit;
    uint8 status;
    address[] participant;
    bytes32[] parterRandomKey;
  }


  /*** STORAGE ***/

  Token[] tokens;

  mapping (uint256 => address) public tokenIndexToOwner;
  mapping (address => uint256) ownershipTokenCount;
  mapping (uint256 => address) public tokenIndexToApproved;


  /*** INTERNAL FUNCTIONS ***/

  function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
    return tokenIndexToOwner[_tokenId] == _claimant;
  }

  function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
    return tokenIndexToApproved[_tokenId] == _claimant;
  }

  function _approve(address _to, uint256 _tokenId) internal {
    tokenIndexToApproved[_tokenId] = _to;

    emit Approval(tokenIndexToOwner[_tokenId], tokenIndexToApproved[_tokenId], _tokenId);
  }

  function _transfer(address _from, address _to, uint256 _tokenId) internal {
    ownershipTokenCount[_to]++;
    tokenIndexToOwner[_tokenId] = _to;

    if (_from != address(0)) {
      ownershipTokenCount[_from]--;
      delete tokenIndexToApproved[_tokenId];
    }

    emit Transfer(_from, _to, _tokenId);
  }

  function _mint(address _owner, uint64 open_time, uint32 _limit) internal returns (uint256 tokenId) {
    Token memory token = Token({
      mintedBy: _owner,
      createTime: uint64(now),
      openTime: open_time,
      limit: _limit,
      status: 0,
      participant: new address[](0),
      parterRandomKey: new bytes32[](0)
    });
    tokenId = tokens.push(token) - 1;

    _transfer(0, _owner, tokenId);
  }


  /*** ERC721 IMPLEMENTATION ***/

  function supportsInterface(bytes4 _interfaceID) external view returns (bool) {
    return ((_interfaceID == InterfaceID_ERC165) || (_interfaceID == InterfaceID_ERC721));
  }

  function totalSupply() public view returns (uint256) {
    return tokens.length;
  }

  function balanceOf(address _owner) public view returns (uint256) {
    return ownershipTokenCount[_owner];
  }

  function ownerOf(uint256 _tokenId) external view returns (address owner) {
    owner = tokenIndexToOwner[_tokenId];

    require(owner != address(0));
  }

  function approve(address _to, uint256 _tokenId) external {
    require(_owns(msg.sender, _tokenId));

    _approve(_to, _tokenId);
  }

  function transfer(address _to, uint256 _tokenId) external {
    require(_to != address(0));
    require(_to != address(this));
    require(_owns(msg.sender, _tokenId));

    _transfer(msg.sender, _to, _tokenId);
  }

  function transferFrom(address _from, address _to, uint256 _tokenId) external {
    require(_to != address(0));
    require(_to != address(this));
    require(_approvedFor(msg.sender, _tokenId));
    require(_owns(_from, _tokenId));

    _transfer(_from, _to, _tokenId);
  }

  function tokensOfOwner(address _owner) external view returns (uint256[]) {
    uint256 balance = balanceOf(_owner);

    if (balance == 0) {
      return new uint256[](0);
    } else {
      uint256[] memory result = new uint256[](balance);
      uint256 maxTokenId = totalSupply();
      uint256 idx = 0;

      uint256 tokenId;
      for (tokenId = 1; tokenId <= maxTokenId; tokenId++) {
        if (tokenIndexToOwner[tokenId] == _owner) {
          result[idx] = tokenId;
          idx++;
        }
      }
    }

    return result;
  }

}

contract ZeroGame is ZeroToken {
  function add_parter (uint256 _tokenId, bytes32 _value) internal {
    tokens[_tokenId].participant.push(msg.sender);
    tokens[_tokenId].parterRandomKey.push(_value);
  }
  /*** OTHER EXTERNAL FUNCTIONS ***/

  function createZero(uint64 open_time, uint32 _limit) external returns (uint256) {
    return _mint(msg.sender, open_time, _limit);
  }

  function len() external view returns(uint256) {
    return tokens.length;
  }
  
  function getToken(uint256 _tokenId) external view returns (
    address mintedBy, 
    uint32 limit,
    address[] participant,
    uint256 le,
    uint64 openTime,
    uint8 status,
    address winner) {
    Token memory token = tokens[_tokenId];

    mintedBy = token.mintedBy;
    limit = token.limit;
    participant = token.participant;
    le = token.participant.length;
    openTime = token.openTime;
    status = token.status;
    if (status == 2){
      winner = tokenIndexToOwner[_tokenId];
    }
  }

  function  balanceOfToken() external view returns(uint256[]){
    uint256[] memory a = new uint256[](tokens.length);
    uint256 maxlength = tokens.length;
    uint256 idx = 0;
    uint256 resultIndex = 0;

    for (idx; idx< maxlength; idx++){
      if (tokenIndexToOwner[idx] == msg.sender) {
        a[resultIndex] = idx;
        resultIndex++;
      }
    }
    return a;
  }
  
  function _getTokenRandom (uint256 _tokenId) internal view returns(uint256 res) {
    bytes32 _value = tokens[_tokenId].parterRandomKey[0];

    for (uint256 i = 0; i < tokens[_tokenId].parterRandomKey.length; i++) {
        _value = _value ^ tokens[_tokenId].parterRandomKey[i];
    }

    res = uint256(_value) % tokens[_tokenId].participant.length;
  }
  

  function openPrice(uint256 _tokenId) external {
    require(tokens[_tokenId].status == 0);
    require(tokens[_tokenId].openTime <= now);
    require (tokens[_tokenId].participant.length > 0);
    require (tokens[_tokenId].parterRandomKey.length > 0);

    tokens[_tokenId].status = 1;

    uint256 random_index = _getTokenRandom(_tokenId);
    address winner = tokens[_tokenId].participant[random_index];
    address token_owner = tokenIndexToOwner[_tokenId];
    _transfer(token_owner, winner, _tokenId);

    tokens[_tokenId].status = 2;
  }
  

  function  partIn (uint256 _tokenId, bytes32 _value) external {
    require(tokens[_tokenId].status == 0);
    add_parter(_tokenId, _value);
  }
}
