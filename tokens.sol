// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

library ArraySearch {
    function contains(string[] storage arr, string memory val)
        external view returns (bool) {
        for (uint i = 0; i < arr.length; i++)
            if(keccak256(bytes(arr[i])) == keccak256(bytes(val))) return true;
        return false;
    }

    function increment(uint[] storage arr, uint8 porc)
        external view returns (uint[] memory) {
        uint[] memory resul = new uint[](arr.length);
        for (uint i = 0; i < arr.length; i++){
            resul[i] = arr[i] + ((porc / 100) * arr[i]);
        }
        return resul;
    }

    function sum(uint[] storage arr)
        external view returns (uint){
        uint suma = 0;
        for(uint i = 0; i < arr.length; i++){
            suma += arr[i];
        }
        return suma;
    }
}

interface ERC721simplified {

  // EVENTS
  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
  event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

  // APPROVAL FUNCTIONS
  function approve(address _approveed, uint256 _tokenId) external payable;

  // TRANSFER FUNCTION
  function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

  // VIEW FUNCTIONS (GETTERS)
  function balanceOf(address _owner) external view returns (uint256);
  function ownerOf(uint256 _tokenId) external view returns (address);
  function getApproved(uint256 _tokenId) external view returns (address);
}

contract MonsterTokens is ERC721simplified{
    address private creator;
    uint private ids;
    mapping(uint256 => Character) private tokens;
    mapping(address => uint256) private numTokens;

    struct Weapons {
        string[] names; // name of the weapon
        uint[] firePowers; // capacity of the weapon
    }

    struct Character {
        string name; // character name
        Weapons weapons; // weapons assigned to this character
        address property; // ... you must add other fields for handling the token.
        address approved;
        uint numWea; // number of weapons
    }

    modifier onlyAuthority {
        require(msg.sender == creator, "Tienes que ser el creador"); _;
    }

    modifier onlyApproved (uint256 idToken) {
       require(tokens[idToken].property == msg.sender || tokens[idToken].approved == msg.sender, "No estas autorizado para entrar a este token"); _;
    }

    modifier onlyProperty(uint256 idToken, address propert){
        require(tokens[idToken].property == propert, "No eres el propietario del contrato"); _;
    }

    modifier nonEmptyString(string memory str){
        require(bytes(str).length > 0); _;
    }

    constructor(){
        creator = msg.sender;
        ids = 100010;
    }

    function addWeapon(uint256 tokenId, string memory arma, uint firepow)
        external onlyApproved(tokenId){
        require(!ArraySearch.contains(tokens[tokenId].weapons.names,arma));
        uint i = tokens[tokenId].numWea;
        tokens[tokenId].weapons.names[i] = arma;
        tokens[tokenId].weapons.firePowers[i] = firepow;
        tokens[tokenId].numWea++;
    }

    function createMonsterToken(string memory nam, address prop) 
        external onlyAuthority nonEmptyString(nam) returns(uint){
        Weapons memory w;
        Character memory c;

        w.names = new string[](0);
        w.firePowers = new uint[](0);
        
        c.name = nam;
        c.weapons = w;
        c.property = prop;
        c.numWea = 0;
        c.approved = address(0);

        tokens[ids] = c;
        ids++;

        numTokens[prop] += 1;

        return ids-1;
    }

    function incrementFirePower(uint256 tokenId, uint8 porcent)
        external view nonEmptyString(tokens[tokenId].name){
        ArraySearch.increment(tokens[tokenId].weapons.firePowers, porcent);
    }

    function collectProfits()
        external onlyAuthority {
        uint256 total = address(this).balance;
        payable(msg.sender).transfer(total);
    }

        function approve(address approveed, uint256 tokenId)
        external payable onlyProperty(tokenId,msg.sender){
        require(ArraySearch.sum(tokens[tokenId].weapons.firePowers) <= msg.value);
        tokens[tokenId].approved = approveed;
        emit Approval(msg.sender, approveed, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId)
        external payable onlyApproved(tokenId) nonEmptyString(tokens[tokenId].name){
        require(ArraySearch.sum(tokens[tokenId].weapons.firePowers) <= msg.value);
        tokens[tokenId].property = to;
        numTokens[from] -= 1;
        numTokens[to] += 1;
        tokens[tokenId].approved = address(0);

        emit Transfer(from, to, tokenId);
    }

    function balanceOf(address owner)
        external view returns (uint256){
        return numTokens[owner];
    }

    function ownerOf(uint256 tokenId)external view returns (address){
        require(tokens[tokenId].property != address(0));
        return tokens[tokenId].property;
    }

    function getApproved(uint256 tokenId)external view returns (address){
        require(bytes(tokens[tokenId].name).length > 0, "Token no valido");
        return tokens[tokenId].approved;
    }
}

