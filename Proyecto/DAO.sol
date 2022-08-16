// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./IERC20.sol";
import "./ERC20.sol";
import "./SafeMath.sol";
import "./IExecutableProposal.sol";

contract mi_propuesta is IExecutableProposal{
    uint proposea;
    uint votea;
    uint tokenea;
    uint ethere;
    QuadraticVoting qua;
    
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable virtual override{
        qua.withdrawFromProposal(proposalId, 2); // intento de ataque al ejecutar la propuesta sacar tus tokens de ella y sacar mas beneficio, solucionado con locks
        proposea = proposalId;
        votea = numVotes;
        tokenea = numTokens;
        ethere = msg.value;
    }

    function getThisAddress() external view returns(address){
        return address(this);
    }
}

contract QuadraticVoting {

    address public owner; 

    address private token; 
    uint256 public tokenPrice; 
    uint256 private maxNumToken;

    bool public voteOpen;

    uint private currentEther;

    mapping(address => mapping(uint => activeParticipant)) private numVotesParticipants;

    uint private proposalIds;
    mapping(uint => Proposal) private proposals;

    uint public numProposals;
    uint public numParticipants;

    uint[] private pendingProp;
    uint[] private approvedProp;
    uint[] private signalinProp;

    mapping(address => bool) private locks;
    bool private lock;

    struct Proposal{
        uint proposalId;
        string title;
        string description;
        uint256 budget;
        uint256 totalBudget;
        uint256 numVotes;
        uint256 numTokens;
        address dest;
        address creator;
        uint state;
        address[] voters;
    }

    struct activeParticipant {
        uint numVotes;
        bool active;
    }

    constructor(uint prices, uint maxTokens){
        if(prices <= 0 || maxTokens <= 0) { revert(); }

        tokenPrice = prices;
        maxNumToken = maxTokens;
        owner = msg.sender;
        proposalIds = 1;
        numProposals = 0;
        voteOpen = false;
        ERC20 tokenObj = new ERC20("QuadratiToken", "QDA", address(this));
        token = address(tokenObj);
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }

    modifier proposalExists(uint proposaId){
        require(proposaId < proposalIds && (proposals[proposaId].state == 1 || proposals[proposaId].state == 3));
        _;
    }

    modifier isParticipant {
        require (numVotesParticipants[msg.sender][0].active == true);
        _;
    }

    modifier voteIsOpen(){
        require(voteOpen == true);
        _;
    }

    function openVoting() external payable onlyOwner{
        voteOpen = true;
        currentEther = msg.value;
    }

    function addParticipant() external payable {
        require(msg.value >= tokenPrice && numVotesParticipants[msg.sender][0].active == false); // Compruebo que la cantidad proporcionada es mas o igual que un token y que no se había añadido ya antes a este participante

        uint256 numtok = msg.value / tokenPrice; 
        require((IERC20(token).totalSupply() + numtok) <= maxNumToken); // Miramos que no exceden el maximo numero de tokens ya definido
        IERC20(token).mint(msg.sender, numtok); // creamos los tokens necesarios a traves de la interfaz
        currentEther += (msg.value % tokenPrice); // nos quedamos como tip lo sobrante
        numVotesParticipants[msg.sender][0].active = true; // damos de alta al participante
        numParticipants++;
    }

    function addProposal(string memory titulo, string memory descripcion, uint256 presupuesto, address destino) voteIsOpen isParticipant external returns (uint){
        if(presupuesto > 1e30) { revert(); } // fijo el maximo presupuesto a pedir en 1e30 ya que ya es un valor muy alto y evito problemas de vulnerabilidad
        Proposal memory p;
        p.title = titulo; //inicializo las variables de la propuesta
        p.description = descripcion;
        p.budget = presupuesto;
        p.dest = destino;
        p.creator = msg.sender;
        p.proposalId = proposalIds;

        if(presupuesto == 0){
            p.state = 3; // la pongo a signaling
        }
        else{
            p.state = 1; // la pongo a pending
        }

        proposals[proposalIds] = p; // meto el struct de la propuesta en el mapping
        proposalIds++; 
        numProposals++; // aumentamos numero de propuestas no aprobadas
        return proposalIds-1;
    }

    function cancelProposal(uint propoId) voteIsOpen proposalExists(propoId) external {
        require(msg.sender == proposals[propoId].creator && !locks[msg.sender]); // compruebo que sea el creador y que su lock esta abierto para evitar que entre el creador dos veces en la funcion y recuperen x2 sus votos los participantes y nos saquen dinero
        locks[msg.sender] = true; //  cierro lock                                                                                                      

        for(uint i = 0; i < proposals[propoId].voters.length; i++){ // itero en todos los votantes de la propuesta a cancelar para devolver sus tokens
            address addrVoter = proposals[propoId].voters[i]; // saco el address del votante
            uint numberVotes = numVotesParticipants[addrVoter][propoId].numVotes; // el numero de votos que ha realizado
            uint numTok = numberVotes * numberVotes; // aplico la ley cuadratica
            IERC20(token).transfer(addrVoter, numTok); // transfer de los tokens a la cuenta del votante de esta propuesta cancelada
            numVotesParticipants[addrVoter][0].numVotes -= numVotesParticipants[addrVoter][propoId].numVotes; // resto los votos totales del usuario
            numVotesParticipants[addrVoter][propoId].numVotes = 0; // lo pongo a 0
        }

        delete proposals[propoId]; // elimino la propuesta
        numProposals--;

        locks[msg.sender] = false; // abro su lock
    }

    function buyTokens() isParticipant voteIsOpen external payable {
        uint256 numtok = msg.value / tokenPrice; // msg.value en Wei por tanto dividimos para ver cuantos tokens le corresponden, si la division no es entera lo restante se queda para financiar propuestas como "tip"
        require((IERC20(token).totalSupply() + numtok) <= maxNumToken && msg.value > tokenPrice); // Miramos que no exceden el maximo numero de tokens ya definido
        currentEther += (msg.value % tokenPrice); // nos quedamos como tip lo sobrante
        IERC20(token).mint(msg.sender, numtok); // creamos los tokens necesarios a traves de la interfaz
    }

    function sellTokens() isParticipant voteIsOpen external {
        require(IERC20(token).allowance(msg.sender, address(this)) >= IERC20(token).balanceOf(msg.sender) && !locks[msg.sender]); //comprobamos que nos ha dado approve para quitarle los tokens
        locks[msg.sender] = true;
        payable(msg.sender).transfer(IERC20(token).balanceOf(msg.sender) * tokenPrice); // transferimos la cantidad que le corresponde al que envia
        IERC20(token).burnFrom(msg.sender, IERC20(token).balanceOf(msg.sender)); // quemamos los 
        if(IERC20(token).balanceOf(msg.sender) == 0 && numVotesParticipants[msg.sender][0].numVotes == 0){ // si ya no tiene tokens ni ha depositado ningun voto pasa a dejar de ser participante
            numVotesParticipants[msg.sender][0].active = false;
            numParticipants--;
        }
        locks[msg.sender] = false;
    }

    function getERC20() isParticipant external view returns(address){
        return token;
    }

    function getPendingProposals() voteIsOpen external returns (uint[] memory){
        delete pendingProp; // recupero gas vaciando el array antiguo
        for(uint i = 1; i < proposalIds; i++){
            if (proposals[i].state == 1) { // está en pending
                pendingProp.push(proposals[i].proposalId); // y lo lleno otra vez con los nuevos valores
            }
        }
        return pendingProp;
    }

    function getApprovedProposals() voteIsOpen external returns (uint[] memory){
        delete approvedProp; // recupero gas vaciando el array antiguo
        for(uint i = 1; i < proposalIds; i++){
            if (proposals[i].state == 2) { // está en accepted
                approvedProp.push(proposals[i].proposalId); // y lo lleno otra vez con los nuevos valores
            }
        }
        return approvedProp;
    }

    function getSignalingProposals() voteIsOpen external returns (uint[] memory){
        delete signalinProp; // recupero gas vaciando el array antiguo
        for(uint i = 1; i < proposalIds; i++){
            if (proposals[i].state == 3) { // es signaling
                signalinProp.push(proposals[i].proposalId); // y lo lleno otra vez con los nuevos valores
            }
        }
        return signalinProp;
    }

    function getProposalInfo(uint proposId) voteIsOpen external view returns (Proposal memory){
        require(proposId < proposalIds);
        return proposals[proposId];
    }

    function getThisAdress() external view returns(address){
        return address(this);
    }

    function stake(uint proposId, uint votes) isParticipant voteIsOpen proposalExists(proposId) external {                                                                                                  
        uint256 oldVotes = numVotesParticipants[msg.sender][proposId].numVotes; // cojo los votos que ya habia depositado el participante x en la propuesta x
        uint256 newVotes = SafeMath.mul(SafeMath.add(votes, oldVotes), SafeMath.add(votes, oldVotes)); // compruebo que no haga overflow con los votos que ha intentado pasar el participante y elevo al cuadrado para ver cual seria la cantidad en tokens final que tiene que a ver
        uint256 diffVotes = newVotes - (oldVotes**2); // lo resto con lo anteriormente ya despositado

        require(((IERC20(token).balanceOf(msg.sender)) >= diffVotes) && ((IERC20(token).allowance(msg.sender, address(this))) >= diffVotes) && !locks[msg.sender]); // compruebo que el participante tiene los tokens suficientes para realizar este voto y que me ha dado approve
        locks[msg.sender] = true;                                                                                                                                   // comprobamos que el lock del participante no esta ya cogido para evitar intentos de votar dos veces a la vez y que salga por el mismo precio para luego realizar un retiro y que salgan con beneficios
        IERC20(token).transferFrom(msg.sender, address(this), diffVotes); // realizamos el transfer de su cuenta a la nuestra

        if (numVotesParticipants[msg.sender][proposId].numVotes == 0) { // si es nuevo votante meto su adress en el array de los votantes a esa propuesta
            proposals[proposId].voters.push(msg.sender);
        }

        numVotesParticipants[msg.sender][proposId].numVotes += votes; // aumento el numero de votos del usuario a la propuesta
        numVotesParticipants[msg.sender][0].numVotes += votes; // aumento el numero de votos total del usuario
        proposals[proposId].numTokens += diffVotes; // aumento el número de tokens a la propuesta
        proposals[proposId].numVotes += votes; // aumento el numero de votos de la propuesta
        proposals[proposId].totalBudget += (diffVotes * tokenPrice); // aumento el dinero total que hay en la propuesta
        locks[msg.sender] = false;

        if ( proposals[proposId].state == 1) {   _checkAndExecuteProposal(proposId); } // si es pending compruebo si ha llegado a su objetivo, si lo ha conseguido la ejecuto
    }

    function withdrawFromProposal(uint votes, uint proposId) isParticipant voteIsOpen proposalExists(proposId) external {
        require(!lock && numVotesParticipants[msg.sender][proposId].numVotes >= votes); // comprobamos que ha depositado como minimo los votos que quiere sacar en la propuesta 
        lock = true;
        uint256 oldVotes = numVotesParticipants[msg.sender][proposId].numVotes;
        uint256 newVotes = SafeMath.mul(SafeMath.sub(oldVotes, votes), SafeMath.sub(oldVotes, votes));
        uint256 diffVotes = (oldVotes**2) - newVotes; // calculo los tokens que le corresponden

        IERC20(token).transfer(msg.sender, diffVotes); // le envio los tokens que había depositado mediante un transfer

        numVotesParticipants[msg.sender][proposId].numVotes -= votes; // decremento los votos del participante a la propuesta
        numVotesParticipants[msg.sender][0].numVotes -= votes; // decremento el numero de votos total del usuario
        proposals[proposId].numTokens -= diffVotes; // decremento el número de tokens a la propuesta
        proposals[proposId].numVotes -= votes; // decremento los votos a la propuesta
        proposals[proposId].totalBudget -= (diffVotes * tokenPrice); // decremento el dinero total de la propuesta

        lock = false;
    }

    function _checkAndExecuteProposal(uint proposaId) internal {
        uint256 budget = proposals[proposaId].budget;
        uint256 totalBudget = proposals[proposaId].totalBudget;
        uint256 totAux = totalBudget * 10;
        uint numberVotes = proposals[proposaId].numVotes;
        uint threshold = numProposals + numParticipants * ((20 + ((budget*10) / totAux)) / 10); // calculo el threshold

        if((currentEther + totalBudget) >= budget && numberVotes > threshold && !lock){  // si se cumple ambas condiciones para aprobar una propuesta, la ejecuto
            lock = true; // activo el lock por si al ejecutar la funcion en el contrato externo intentan entrar a withdrawFromProposal para sacar tokens de la propuesta cuando ya no se puede porque esta aceptada

            IExecutableProposal(proposals[proposaId].dest).executeProposal{value: budget, gas: 100000} // fijo el gas en 100000 y value en el presupuesto que habían pedido
                (proposaId, numberVotes, proposals[proposaId].numTokens);

            IERC20(token).burn(proposals[proposaId].numTokens); // quemo los tokens asociados a esta propuesta

            currentEther += totalBudget; // aumento el presupuesto con el ether total que le ha llegado a la propuesta
            currentEther -= budget; // le resto el presupuesto que he enviado

            proposals[proposaId].state = 2; // la cambio a accepted
            numProposals--; // decremento el numero de propuestas
            lock = false;
        }
    }

    function closeVoting() voteIsOpen onlyOwner external {
        for(uint i = 0; i < proposalIds; i++){
            uint state = proposals[i].state;
            if (state == 1 || state == 3){ // si se ha quedado en pending o es signaling
                for(uint j = 0; j < proposals[i].voters.length; j++){
                    address participant = proposals[i].voters[j];
                    uint ntok = numVotesParticipants[participant][i].numVotes ** 2;
                    if(ntok > 0) { IERC20(token).transfer(participant, ntok); } // devolvemos los tokens
                    numVotesParticipants[participant][i].numVotes = 0; // pongo el votante x a la propuesta y 0 votos (lo vacío)
                }
                if(state == 3){ // si es signaling ejecuto la propuesta
                    lock = false;
                    IExecutableProposal(proposals[i].dest).executeProposal{value: 0, gas: 100000}
                        (i,proposals[i].numVotes,proposals[i].budget);

                    IERC20(token).burn(proposals[i].totalBudget / proposals[i].numVotes);
                    currentEther += proposals[i].totalBudget;

                    lock = true;
                }
                delete proposals[i]; // elimino la propuesta
            }

            else if (state == 2){ // si ya se habia aprobado solo elimino
                delete proposals[i];
            }
        }

        payable(owner).transfer(address(this).balance); // transfiero al creador lo que ha sobrado

        proposalIds = 1; // pongo los ids de las propuestas a uno para empezar desde ahi a asignar otra vez  
        numProposals = 0; // numero de propuestas no aprobadas a 0
        voteOpen = false;  // cierro votación
    }
}
