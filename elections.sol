// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;
contract DhondtElectionRegion{
    mapping(uint => uint)private weights;
    uint private regionId;
    uint[] private results;

    constructor(uint idreg, uint numPar){
        savedRegionInfo();
        regionId = idreg;
        results = new uint[](numPar);
    }

    function savedRegionInfo() private{
        weights[28] = 1; // Madrid
        weights[8] = 1; // Barcelona
        weights[41] = 1; // Sevilla
        weights[44] = 5; // Teruel
        weights[42] = 5; // Soria
        weights[49] = 4; // Zamora
        weights[9] = 4; // Burgos
        weights[29] = 2; // Malaga
    }

    function registerVote(uint parti) internal returns(bool){
        bool val = false;
        //if (parti < results.length){
        val = true;
        results[parti] += weights[regionId];
        //}

        return val;
    }

    function getResul() internal view returns (uint[] memory){
        return results;
    }
}

abstract contract PollingStation{
    bool public votingFinished;
    bool private votingOpen;
    address private president;

    constructor(address presi){
        president = presi;
        votingFinished = false;
        votingOpen = false;
    }

    modifier onlyPresident {
        require(msg.sender == president); _;
    }

    modifier voteOpen {
        require (votingOpen == true); _;
    }

    function openVoting() external onlyPresident{
        votingOpen = true;
    }

    function closeVoting() external onlyPresident{
        votingFinished = true;
        votingOpen = false;
    }

    function castVote(uint ident) external virtual;
    function getResults() external virtual returns (uint[] memory);

}

contract DhondtPollingStation is PollingStation, DhondtElectionRegion{
    constructor(address presi, uint numPar, uint idreg) PollingStation(presi) DhondtElectionRegion(idreg, numPar) {

    }

    function castVote(uint ident) external override voteOpen{
        DhondtElectionRegion.registerVote(ident);
    }

    function getResults() external view override returns (uint[] memory){
        require(votingFinished == true, "La votacion aun no ha terminado");
        return DhondtElectionRegion.getResul();
    }

    function getLongitud() external view returns(uint){
        return DhondtElectionRegion.getResul().length;
    }

}

contract Election {
    mapping(uint => DhondtPollingStation) public sedesElec;
    uint[] idregions;
    address[] votantes;
    address creator;
    uint numPartidos;

    constructor(uint numParti){
        creator = msg.sender;
        numPartidos = numParti;
    }

    modifier onlyAuthority {
        require (msg.sender == creator, "Tienes que ser el creador"); _;
    }

    modifier freshId(uint regionId) {
        require (sedesElec[regionId] == DhondtPollingStation(0x0), "Region existente"); _;
    }

    modifier validId(uint regionId) {
        require (sedesElec[regionId] != DhondtPollingStation(0x0), "Region inexistente"); _; 
    }

    function yaVotado(address addr) internal view returns(bool){
        uint i = 0;
        uint lengt = votantes.length;
        bool encont = false;
        while(i < lengt && !encont){
            if(votantes[i] == addr){
                encont = true;
            }
            i++;
        }

        return encont;
    }

    function apuntarLista (uint[] memory votaReg, uint[] memory votaFinal) internal pure returns(uint[] memory){
        uint i = 0;
        uint lengt = votaReg.length;

        while(i < lengt){
            votaFinal[i] += votaReg[i];
            i++;
        }

        return votaFinal;
    }

    function createPollingStation(uint idreg, address preside) external freshId(idreg) onlyAuthority returns(address){
        DhondtPollingStation p = new DhondtPollingStation (preside, numPartidos, idreg);
        sedesElec[idreg] = p;
        idregions.push(idreg);

        return address(p);
    }

    function castVote(uint idreg, uint part) external validId(idreg) {
        require(!yaVotado(msg.sender), "Ya has votado");
        sedesElec[idreg].castVote(part);
        votantes.push(msg.sender);
    }

    function getResults() external view onlyAuthority returns (uint[] memory){
        uint i = 0;
        uint j;
        uint lengt2;
        uint lengt = idregions.length;
        uint[] memory resultados = new uint[](numPartidos);
        uint[] memory aux;

        while(i < lengt){
            j = 0;
            aux = sedesElec[idregions[i]].getResults();
            lengt2 = aux.length;
            while(j < lengt2){
                resultados[j] += aux[j];
                j++;
            }            
            i++;
        }

        return resultados;
    }
}