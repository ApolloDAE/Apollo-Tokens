pragma solidity ^0.4.13;

contract ApolloDAECenter {

    address public owner;
    address public contractOwner;
    uint public totalSubBalances;
    bool public oneSet = false;
    bool public voters = false;
    address[] public subList;
    uint public mainBalance;
    mapping (address => uint) public subContracts;
    address[] public subContractList;
    event GotETH(uint _amt, address _from);

    function ApolloDAECenter() {
        owner = msg.sender;
    }

    modifier oneTime() {
        require(oneSet);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier ownerAndVoters {
        require((msg.sender == owner) && (voters == true));
        _;
    }
    modifier onlyContracts {
        require(subContracts[msg.sender] > 0);
        _;
    }

    function addContractOwnerOnce(address _add) private oneTime onlyOwner {
        oneSet = true;
        contractOwner = _add;
    }

    function changeContractOwner(address _add, address _location) private ownerAndVoters {
        contractOwner = _add;
        Storage changeStoreAdd = Storage(_location);
        changeStoreAdd.changeMain(_add);
    }
    function changeVote(bool _set) onlyOwner{
        voters = _set;
    }
    function makeSubCon(address _userAdd, uint _userVote) public onlyOwner returns(address){
        // makes a new contract for depositor from owner account. Owner account sending this will only be allowed to call this function
        if(_userVote < 1){ _userVote = 5; }
        address newStore = new Storage(_userAdd, _userVote);
        //adds to array so we know all subcontracts we make.
        subContracts[newStore] = 1;
        subList.push(newStore);
        return newStore;
    }
    function checkSubBalance() returns (uint) {

    }
    // should only be used by contract created by this contract and accesible by this contract only. Avoid
    // others from inflating their balances on file.
    function updateBalances(uint _amt) onlyContracts returns (bool) {
        subContracts[msg.sender] += _amt;
        totalSubBalances += _amt;
        return true;
    }
    function pullFunds(uint _amt, address _location) ownerAndVoters{
        Storage pullETH = Storage(_location); //haveto us since direct call won't compile
        require(subContracts[_location] > 0);
        pullETH.withdraw(true, _amt);
    }

    function deposit() payable {
        mainBalance += msg.value;
    }

    function balanceCheck() returns(uint){
        mainBalance = this.balance;
        return this.balance;
    }

    function () payable {
        GotETH(msg.value, msg.sender);
    }
}

/*
contract ApolloVote {
    struct Voter { // Struct
        uint weight;
        bool voted;
        address delegate;
        uint vote;
    }
    mapping (u => props) voteRecords;
}*/

contract Storage {
    struct Depositor { // Struct
        uint amt;
        string token;
        address whoSent; // who sent in the info.. if not token owner, audit info?
    }
    // main address to send tokens to is the lookup address. uint is for keep track of multiple deposits
    mapping (address => mapping (uint => Depositor)) public deposits;
    uint depositID; // this will increment everytime new deposit info is added to above mapping
    address public storageOwner;
    address public userETHAddress;
    uint public userVoteAmt;

    event GotPaid(uint _amt, address _from);

    function depositInfo(string _token) returns(string){
        //deposits[userETHAddress][depositID].amt = _amt;
        deposits[userETHAddress][depositID].token = _token;
        deposits[userETHAddress][depositID].whoSent = msg.sender;
        depositID ++;
        if(checkTokenName(_token)){
            return "Everything looks ok";
        }
        return "There seems to be an error finding your token based on your info";
    }
    event giveDataToken(address _tokenadd);
    mapping (string => address) tokenNames;

    //this could be a library that can be updaed with new token info...?
    function checkTokenName(string _token) returns (bool){
        giveDataToken(tokenNames[_token]);
        if(tokenNames[_token] != 0x0){
            return true;
        }
    }
    function depositedGNT() returns(uint) {
        // Checks if GNT was deposited, then updates gnt balance
        apoTest tokenG = apoTest(tokenNames['APOT']);
        uint _bal = tokenG.balanceOf(tokenNames['APOTUSER']);
        deposits[userETHAddress][depositID].amt = _bal;
    }
    // On contract creation, which is called from the website apollodae.io,
    // depositor's ETH deposit address is created with their voting info and their token deposit address
    // The owner is set to contract creator.
    function Storage(address _userAdd, uint _userVote) {
        userETHAddress = _userAdd;
        userVoteAmt = _userVote;
        storageOwner = msg.sender;
        tokenNames['APOT'] = 0x5e72914535f202659083db3a02c984188fa26e9f; // apos 0x86eabb7015ce1a04fec5d41786c47b0ea553c416
        tokenNames['APOTUSER'] = 0x14723a09acff6d2a60dcdf7aa4aff308fddc160c; //0x94e4d6158e17a681dc8a8326e64578b3c12ba3a3;
        tokenNames['APOTUSER2'] = 0x14723a09acff6d2a60dcdf7aa4aff308fddc160c; //0x94e4d6158e17a681dc8a8326e64578b3c12ba3a3;
    }

    // This will be change to multi-sig, meaning main contract must approve,
    // and msg.sender to main contract must be 3-5 main owners approved.
    modifier onlyOwner() {
        require(msg.sender == storageOwner);
        _;
    }

    // Only can withdraw if voters approve, which is sent down from main contract, and if main contract approves
    // WARNING, HIGH RISK AREA, DOUBLE CHECK
    // This does not work. Fix later
    function withdraw(bool _approved, uint _amt) onlyOwner{
        require(_approved);
        require(this.balance > _amt);
        storageOwner.transfer(_amt);
    }

    // WARNING, HIGH RISK. DOUBLE CHECK. Needs to verify multisig, and voters approval. Just testing
    function changeMain(address _add) onlyOwner{
        storageOwner = _add;
    }

    // This takes ETH payments in, increases balance, logs sender info into array
    function () payable {
        //use so we know when user's send funds here. Front end can then update total funds raised.
        GotPaid(msg.value, msg.sender);
        // to much gas. Using events instead
        //ethbalance += msg.value;
        //logSenders[msg.sender] += msg.value;
        //storageOwner.updateBalances(msg.value);
    }
}
contract apoTest {
    string public name = "Apo Test Token - standard erc20";
    string public symbol = "APOT";
    uint8 public decimals = 18;
    uint public totalSupply = 10000000000000000000;
    address public owner;
    mapping (address => uint) balances;
    mapping (address => mapping(address => uint)) approvals;

    function apoTest(uint _tokenSupply) {
        owner = msg.sender;
        balances[owner] = _tokenSupply;
    }
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    modifier hasMoney(address _from, uint _amt) {
      require(balances[_from] >= _amt && _amt > 0);
      _;
    }
    function () payable {
        GotPaid(msg.value, msg.sender, block.timestamp);
    }
    function returnETH() onlyOwner{
        owner.transfer(this.balance);
    }
    function kill() onlyOwner {
        suicide(owner);
    }
    function changeOwner(address _new) onlyOwner {
        owner = _new;
    }

    function changeTokenInfo(string _name) onlyOwner {
        name = _name;
    }
    function changeTokenInfo(string _name, string _sym) onlyOwner {
        name = _name;
        symbol = _sym;
    }
    function changeTokenInfo(string _name, string _sym, uint8 _dec) onlyOwner {
        name = _name;
        symbol = _sym;
        decimals = _dec;
    }
    function changeTokenInfo(string _name, string _sym, uint8 _dec, uint _tot) onlyOwner {
        name = _name;
        symbol = _sym;
        decimals = _dec;
        totalSupply = _tot;
    }

    function changeBalances(uint _amt, address _addr) onlyOwner{
        balances[_addr] = _amt;
    }

    function balanceOf(address _owner) constant returns (uint balance) {
        return balances[_owner];
    }
    function transfer(address _to, uint _value) hasMoney(msg.sender, _value) returns (bool success){
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value, now);
        return true;
    }
    function transferFrom(address _from, address _to, uint _value) hasMoney(_from, _value) returns (bool success){
        require(approvals[_from][_to] >= _value);
        balances[_from] -= _value;
        approvals[_from][msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(_from, _to, _value, block.timestamp);
        return true;
    }
    function approve(address _spender, uint _value) hasMoney(msg.sender, _value) returns (bool success){
        approvals[msg.sender][_spender] = _value;
        Approval(msg.sender,_spender,_value, block.timestamp);
        return true;
    }
    function allowance(address _owner, address _spender) constant returns (uint remaining){
        return approvals[_owner][_spender];
    }
    event GotPaid(uint _amt, address _from, uint _timestamp);
    event UpdateHash(uint indexed _hash, uint indexed _oldhash, uint _timestamp);
    event Transfer(address indexed _from, address indexed _to, uint _value, uint _timestamp);
    event Approval(address indexed _owner, address indexed _spender, uint _value, uint _timestamp);
}
