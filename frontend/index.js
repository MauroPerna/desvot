
//------Contrato------//
let desvot;
let vrfCoordinatorV2Mock;
let provider;
let accountsGanache;
let states = ["Created", "Started", "Tie", "Ended"];
let electionState;

// Conexion con Metamask
async function connectMetamask() {
    if (typeof window.ethereum !== undefined) {
        provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner()
        const address = await signer.getAddress();
        console.log(`Conectado con Metamask. Dirección de la cuenta: ${address}`);
        return signer;
    } else {
        throw new Error('Por favor, instale Metamask.');
    }
}

async function connectContract() {
    provider = new ethers.providers.Web3Provider(window.ethereum); 
    const desvotABI = await fetch('../deployments/ganache/Desvot.json');
    const vrfCoordinatorV2MockABI = await fetch('../deployments/ganache/VRFCoordinatorV2Mock.json');
    const desvotJSON = await desvotABI.json();
    const vrfCoordinatorV2MockJSON = await vrfCoordinatorV2MockABI.json();
    const desvotAddress = desvotJSON["address"];
    const vrfCoordinatorV2MockAddress = vrfCoordinatorV2MockJSON["address"];
    desvot = new ethers.Contract(desvotAddress, desvotJSON.abi, provider);
    vrfCoordinatorV2Mock = new ethers.Contract(vrfCoordinatorV2MockAddress, vrfCoordinatorV2MockJSON.abi, provider);
    console.log(desvot);
    console.log(vrfCoordinatorV2Mock);
}

async function getContractWithSigner() {
}

async function handleEvent() {
    try {
    /*
        await randomNumberConsumerV2.requestRandomWords()
        const requestId: BigNumber = await randomNumberConsumerV2.s_requestId()
        vrfCoordinatorV2Mock.fulfillRandomWords(requestId, randomNumberConsumerV2.address)
    */

        const signer = provider.getSigner();
        const desvotWithSigner = desvot.connect(signer);
        const vrfCoordinatorV2MockWithSigner = vrfCoordinatorV2Mock.connect(signer);
        await desvotWithSigner.requestRandomWords()
        const requestId = await desvotWithSigner.s_requestId();
        console.log("=====>", requestId.toNumber())
        console.log("=====>", desvot.address)
        await vrfCoordinatorV2MockWithSigner.fulfillRandomWords(requestId, desvot.address)
    } catch (error) {
        console.error(error)
    }
    // var inputValue = document.getElementById("inputParam").value;
    // const voters = await contract.voters(inputValue);
    // console.log(voters)
    // const candidates = await contract.candidates(inputValue);
    // if(voters.isRegistered) alert("is a voter");
    // if(candidates.isRegistered) alert("is a candidate");
    // if(!voters.isRegistered && !candidates.isRegistered) alert("is owner");
}

function subscribeToEvents() {
    desvot.on("Voted", (eventArgs) => {
        document.getElementById("inpt-address").value = eventArgs;
    })
    desvot.on("ChangeVotingState", (eventArgs) => {
        document.getElementById("inpt-state-value").value = states[eventArgs];
    });
    desvot.on("WinnerAnnounced", (addressWinner, votesWinner, addressRunnerUp, votesRunnerUp) => {
        document.getElementById("winner-add").value = addressWinner;
        document.getElementById("winner-votes").value = votesWinner;
        document.getElementById("runner-up-ad").value = addressRunnerUp;
        document.getElementById("runner-up-votes").value = votesRunnerUp;
    });
    desvot.on("FundsTransfered", (eventArgs) => {
        const totalAmount = eventArgs.toString();
        const totalAmountInEther = ethers.utils.formatUnits(totalAmount, "ether");
        document.getElementById("total-amount").value = `${totalAmountInEther} eth`;
    });
    desvot.on("ReturnedRandomness", (randomWords) => {
        // const convertedWords = randomWords.map(word => word.toString());
        // console.log("Converted random words:", convertedWords);
        console.log("Randooooom", randomWords)
    });
}
//------Candidatos------//

async function payFee() {
    const registrationFee = await desvot.registrationFee();

    try {
        const signer = provider.getSigner();
        const contractWithSigner = desvot.connect(signer);
        const transaction = await contractWithSigner.payFee({ value: registrationFee.toString() });
        console.log(transaction);
    } catch (error) {
        throw new Error(error);
    }
}

async function registerCandidate() {
    try {
        const signer = provider.getSigner();
        const contractWithSigner = desvot.connect(signer);
        const inputElement = document.getElementById("candidate_address_ap");
        const address = inputElement.value;;
        const transaction = await contractWithSigner.registerCandidate(address);
        console.log(transaction)
    } catch (error) {
        alert(error.data.data.reason)
    }
}

//------Votantes------//
async function registerVoter() {
    try {
        const signer = provider.getSigner();
        const contractWithSigner = desvot.connect(signer);
        const transaction = await contractWithSigner.registerVoter();
        console.log(transaction);
    } catch (error) {
        alert(error.data.data.reason)
    }
}

//------Votacion------//
async function startVoting() {
    try {
        const signer = provider.getSigner();
        const contractWithSigner = desvot.connect(signer);
        const transaction = await contractWithSigner.startVoting();
        console.log(transaction);
    } catch (error) {
        alert(error.data.data.reason);
    }
}

async function consultVoting() {
    try {
        const algo = await desvot.callStatic.randomWord();
        console.log(algo.toNumber())
        const rx = await desvot.callStatic.electionState();
        document.getElementById("inpt-state-value").value = states[rx];
        console.log(rx);
    } catch (error) {
        console.error(error);
    }
}

async function endVoting() {
    try {
        const signer = provider.getSigner();
        const contractWithSigner = desvot.connect(signer);
        const tx = await contractWithSigner.scrutiny();
        const totalVotes = await desvot.callStatic.totalVotes();
        const totalAmount = await desvot.callStatic.totalFunds();
        const totalAmountInEther = ethers.utils.formatUnits(totalAmount.toString(), "ether");
        document.getElementById("total-votes").value = totalVotes;
        document.getElementById("total-amount").value = `${totalAmountInEther} eth`;
        console.log(tx);
    } catch (error) {
        alert(error.data.data.reason);
    }
}

async function vote() {
    const candidateElement = document.getElementById('candidate_address_to_vote');
    const candidateAddress = candidateElement.value;
    try {
        const signer = provider.getSigner();
        const contractWithSigner = desvot.connect(signer);
        const tx = await contractWithSigner.vote(candidateAddress);
        console.log(tx);
    } catch (error) {
        alert(error.data.data.reason);
    }
}

async function voteBalotaje() {
    const candidateElement = document.getElementById('candidate_address_to_vote_balotaje');
    const candidateAddress = candidateElement.value;
    try {
        const signer = provider.getSigner();
        const contractWithSigner = desvot.connect(signer);
        const tx = await contractWithSigner.voteBalotaje(candidateAddress);
        console.log(tx);
    } catch (error) {
        alert(error.data.data.reason);
    }
}


async function consultFee() {
    let registrationFee;
    try {
        registrationFee = await desvot.registrationFee();
    } catch (error) {
        alert(error.data.data.reason);
    }
    const registrationFeeInEther = ethers.utils.formatUnits(registrationFee, "ether");
    alert(`Registration Fee ${registrationFeeInEther} ethers`);
}


//------MAIN------//

async function main() {
    await connectContract();
    subscribeToEvents();
    let tx = await desvot.callStatic.electionState();
    electionState = states[tx]
}
main();
