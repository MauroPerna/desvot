// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Desvot is VRFConsumerBaseV2 {
    enum ElectionState {
        CREATED,
        STARTED,
        TIE,
        ENDED
    }

    address payable public owner;
    uint public registrationFee;
    uint public totalVotes;
    uint public totalFunds;
    ElectionState public electionState;

    struct Candidate {
        bool feePaid;
        bool isRegistered;
        uint votesReceived;
        bool balotaje;
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        bool hasVotedInBalotaje;
    }

    mapping(address => Candidate) public candidates;
    mapping(address => Voter) public voters;

    event Voted(address candidateAddress);
    event ChangeVotingState(ElectionState state);
    event WinnerAnnounced(
        address winnerAddress,
        uint votesWinner,
        address addressRunnerUp,
        uint votesRunnerUp
    );
    event FundsTransfered(uint balanceCollected);

    address[] candidatesAddress;
    address[] tiedCandidates;
    address[] randomSelectionCandidates;

    // ============================== VRF CONFIG ==============================
    VRFCoordinatorV2Interface immutable COORDINATOR;

    uint64 immutable s_subscriptionId;
    bytes32 immutable s_keyHash;
    uint32 constant CALLBACK_GAS_LIMIT = 100000;
    uint16 constant REQUEST_CONFIRMATIONS = 1;
    uint32 constant NUM_WORDS = 2;

    uint256[] public s_randomWords;
    uint public randomWord;
    uint256 public s_requestId;

    event ReturnedRandomness(uint256[] randomWords);

    constructor(
        uint _registrationFee,
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash
    ) VRFConsumerBaseV2(vrfCoordinator) {
        owner = payable(msg.sender);
        registrationFee = _registrationFee;
        electionState = ElectionState.CREATED;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }

    //==========================================================================

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can perform this action"
        );
        _;
    }
    modifier notOwner() {
        require(msg.sender != owner, "Owner cannot perform this action");
        _;
    }
    modifier onlyCreated() {
        require(
            electionState == ElectionState.CREATED,
            "This action can only perform in election state CREATED"
        );
        _;
    }
    modifier onlyStarted() {
        require(
            electionState == ElectionState.STARTED,
            "This action can only perform in election state STARTED"
        );
        _;
    }
    modifier onlyTie() {
        require(
            electionState == ElectionState.TIE,
            "This action can only perform in election state TIE"
        );
        _;
    }
    modifier onlyEnded() {
        require(
            electionState == ElectionState.ENDED,
            "This action can only perform in election state ENDED"
        );
        _;
    }

    // ========================================== Functions ==========================================

    function payFee() public payable onlyCreated notOwner {
        require(msg.value == registrationFee, "Incorrect value");
        candidates[msg.sender] = Candidate(true, false, 0, false);
        totalFunds += msg.value;
    }

    function registerCandidate(
        address _candidateAddress
    ) public onlyOwner onlyCreated {
        require(
            candidates[_candidateAddress].feePaid,
            "The candidate must paid the registration fee"
        );
        require(
            !candidates[_candidateAddress].isRegistered,
            "The candidate is already registered"
        );
        require(
            !voters[_candidateAddress].isRegistered,
            "The candidate cannot be a voter"
        );
        require(_candidateAddress != owner, "The owner cannot be a candidate");

        candidates[_candidateAddress].isRegistered = true;
        candidatesAddress.push(_candidateAddress);
    }

    function registerVoter() public onlyCreated notOwner {
        require(
            !voters[msg.sender].isRegistered,
            "The voter is already registered"
        );
        require(
            !candidates[msg.sender].isRegistered,
            "The voter cannot be a candidate"
        );

        voters[msg.sender] = Voter(true, false, false);
    }

    function startVoting() public onlyOwner onlyCreated {
        electionState = ElectionState.STARTED;
        emit ChangeVotingState(electionState);
    }

    function vote(address _candidateAddress) public onlyStarted notOwner {
        require(
            voters[msg.sender].isRegistered,
            "Only a voter registered can perform this action"
        );
        require(
            !voters[msg.sender].hasVoted,
            "The voter has already emit vote"
        );
        require(
            candidates[_candidateAddress].isRegistered,
            "The candidate is not registered"
        );

        voters[msg.sender].hasVoted = true;
        candidates[_candidateAddress].votesReceived++;
        totalVotes++;
        emit Voted(_candidateAddress);
    }

    function scrutiny() public payable onlyOwner {
        require(
            electionState == ElectionState.STARTED ||
                electionState == ElectionState.TIE,
            "This action can only perform in election state STARTED or TIE"
        );

        bool isTie = checkTie();

        if (isTie && electionState == ElectionState.STARTED) {
            balotaje();
        }

        if (!isTie && electionState == ElectionState.STARTED) {
            endingVote();
        }

        if (!isTie && electionState == ElectionState.TIE) {
            endingVote();
        }

        // if(isTie && electionState == ElectionState.TIE) {
        //     requestRandomWords();
        // }
    }

    function voteBalotaje(address _candidateAddress) public onlyTie notOwner {
        require(
            voters[msg.sender].isRegistered,
            "Only a voter registered can perform this action"
        );
        require(
            !voters[msg.sender].hasVotedInBalotaje,
            "The voter has already emit vote"
        );
        require(
            candidates[_candidateAddress].isRegistered,
            "The candidate is not registered"
        );
        require(
            candidates[_candidateAddress].balotaje,
            "The candidate is not eligible"
        );

        voters[msg.sender].hasVotedInBalotaje = true;
        candidates[_candidateAddress].votesReceived++;
        totalVotes++;
        emit Voted(_candidateAddress);
    }

    function endingVote() public onlyOwner {
        require(
            electionState == ElectionState.STARTED ||
                electionState == ElectionState.TIE,
            "This action can only perform in election state STARTED or TIE"
        );
        electionState = ElectionState.ENDED;
        address winner;
        address runnerUp;
        uint maxVotes;
        uint maxVotesRunnerUp;
        (winner, maxVotes, runnerUp, maxVotesRunnerUp) = announceWinner();
        emit ChangeVotingState(electionState);
        emit WinnerAnnounced(winner, maxVotes, runnerUp, maxVotesRunnerUp);
        uint fundsTransfered = transferFunds();
        emit FundsTransfered(fundsTransfered);
    }

    // ===================================== Private Functions =====================================

    function announceWinner()
        private
        view
        onlyOwner
        onlyEnded
        returns (address, uint, address, uint)
    {
        address winner;
        address runnerUp;
        uint maxVotes;
        uint maxVotesRunnerUp;

        for (uint256 i = 0; i < candidatesAddress.length; i++) {
            address candidateAddress = candidatesAddress[i];
            uint candidateVotes = candidates[candidateAddress].votesReceived;

            if (candidateVotes > maxVotes) {
                maxVotesRunnerUp = maxVotes;
                runnerUp = winner;
                maxVotes = candidateVotes;
                winner = candidateAddress;
            } else if (candidateVotes > maxVotesRunnerUp) {
                maxVotesRunnerUp = candidateVotes;
                runnerUp = candidateAddress;
            }
        }

        return (winner, maxVotes, runnerUp, maxVotesRunnerUp);
    }

    function transferFunds() private returns (uint) {
        uint balance = address(this).balance;
        (bool success, ) = address(owner).call{value: balance}("");
        require(success, "The transaction fail!");
        return balance;
    }

    function checkTie() private returns (bool) {
        uint maxVotes = 0;
        bool isTie = false; // It is not a tie

        if (electionState == ElectionState.STARTED) {
            for (uint i = 0; i < candidatesAddress.length; i++) {
                address candidateAddress = candidatesAddress[i];
                uint candidateVotes = candidates[candidateAddress]
                    .votesReceived;

                if (candidateVotes > maxVotes) {
                    maxVotes = candidateVotes;
                }
            }

            for (uint256 i = 0; i < candidatesAddress.length; i++) {
                address candidateAddress = candidatesAddress[i];
                uint candidateVotes = candidates[candidateAddress]
                    .votesReceived;

                if (candidateVotes == maxVotes) {
                    tiedCandidates.push(candidateAddress);
                    candidates[candidateAddress].balotaje = true;
                }

                if (tiedCandidates.length > 1) {
                    isTie = true; // It is Tie
                }
            }
        } else {
            for (uint i = 0; i < tiedCandidates.length; i++) {
                address candidateAddress = tiedCandidates[i];
                uint candidateVotes = candidates[candidateAddress]
                    .votesReceived;

                if (candidateVotes > maxVotes) {
                    maxVotes = candidateVotes;
                }
            }

            for (uint256 i = 0; i < tiedCandidates.length; i++) {
                address candidateAddress = tiedCandidates[i];
                uint candidateVotes = candidates[candidateAddress]
                    .votesReceived;

                if (candidateVotes == maxVotes) {
                    randomSelectionCandidates.push(candidateAddress);
                }

                if (randomSelectionCandidates.length > 1) {
                    isTie = true; // It is Tie
                }
            }
        }

        return isTie;
    }

    function balotaje() private onlyOwner onlyStarted {
        for (uint i = 0; i < candidatesAddress.length; i++) {
            address candidateAddress = candidatesAddress[i];
            candidates[candidateAddress].votesReceived = 0;
        }

        electionState = ElectionState.TIE;
        emit ChangeVotingState(electionState);
    }

    function calculateRandomResults() private {
        uint winnerIndex = randomWord % randomSelectionCandidates.length;
        address winnerAddress = randomSelectionCandidates[winnerIndex];
        electionState = ElectionState.ENDED;
        address runnerUp;
        uint maxVotes;
        uint maxVotesRunnerUp;
        emit ChangeVotingState(electionState);
        emit WinnerAnnounced(winnerAddress, maxVotes, runnerUp, maxVotesRunnerUp);
        uint fundsTransfered = transferFunds();
        emit FundsTransfered(fundsTransfered);
    }

    // ============================ VRF METHODS ======================================

    function requestRandomWords() external onlyOwner{
        s_requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
    }
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(requestId == s_requestId, "Invalid requestId");
        s_randomWords = randomWords;
        randomWord = randomWords[0];
        emit ReturnedRandomness(randomWords);
        calculateRandomResults();
    }
}
