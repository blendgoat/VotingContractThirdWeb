// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

// Base
import "@thirdweb-dev/contracts/interfaces/IThirdwebContract.sol";

// Governance
import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";



// Meta transactions
import "@thirdweb-dev/contracts/openzeppelin-presets/metatx/ERC2771ContextUpgradeable.sol";

interface ERC1155 {
    function balanceOf(address owner) external view returns(uint);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns(uint256);
}



contract VoteERC20 is
    Initializable,
    IThirdwebContract,
    ERC2771ContextUpgradeable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable
  
{
    bytes32 private constant MODULE_TYPE = bytes32("VoteERC20");
    uint256 private constant VERSION = 1;

    string public contractURI;
    uint256 public proposalIndex;

    ERC1155 public immutable membershipNFT;
    uint256 public tokenId;

    struct Proposal {
        uint256 proposalId;
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        string description;
    }

    /// @dev proposal index => Proposal
    mapping(uint256 => Proposal) public proposals;

    // solhint-disable-next-line no-empty-blocks
    constructor( uint256 _tokenId,   address _serumAddress)   initializer {
        membershipNFT = ERC1155(_serumAddress);
        tokenId = _tokenId;
    } 
    

    /// @dev Initiliazes the contract, like a constructor.
    function initialize(
        string memory _name,
        string memory _contractURI,
        address[] memory _trustedForwarders,
        address _token,
        uint256 _initialVotingDelay,
        uint256 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        uint256 _initialVoteQuorumFraction

    ) external initializer {
       
        // Initialize inherited contracts, most base-like -> most derived.
        __ERC2771Context_init(_trustedForwarders);
        __Governor_init(_name);
        __GovernorSettings_init(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold);
        __GovernorVotes_init(IVotesUpgradeable(_token));
        __GovernorVotesQuorumFraction_init(_initialVoteQuorumFraction);
        
        // Initialize this contract's state. 
        contractURI = _contractURI;
        
    }
    

    /// @dev Returns the module type of the contract.
    function contractType() external pure returns (bytes32) {
        return MODULE_TYPE;
    }

    /// @dev Returns the version of the contract.
    function contractVersion() public pure override returns (uint8) {
        return uint8(VERSION);
    }

    modifier nftHolderOnly {
        require(membershipNFT.balanceOf(msg.sender) > 0, "You need to own an ERC1155 token before you perform x ");
        _;
    }

    /**
     * @dev See {IGovernor-propose}.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override nftHolderOnly returns (uint256 proposalId) {
        // require(membershipNFT.balanceOf(msg.sender, tokenId) > 0, "You don't own enough Serum NFTs");
        proposalId = super.propose(targets, values, calldatas, description);

        proposals[proposalIndex] = Proposal({
            proposalId: proposalId,
            proposer: _msgSender(),
            targets: targets,
            values: values,
            signatures: new string[](targets.length),
            calldatas: calldatas,
            startBlock: proposalSnapshot(proposalId),
            endBlock: proposalDeadline(proposalId),
            description: description
        });

        proposalIndex += 1;
    }

    /// @dev Returns all proposals made.
    function getAllProposals() external view returns (Proposal[] memory allProposals) {
        uint256 nextProposalIndex = proposalIndex;

        allProposals = new Proposal[](nextProposalIndex);
        for (uint256 i = 0; i < nextProposalIndex; i += 1) {
            allProposals[i] = proposals[i];
        }
    }

    function setContractURI(string calldata uri) external onlyGovernance {
        contractURI = uri;
    }

    // function balanceOf(address account, uint256 id) external view returns (uint256) {

    // }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return GovernorSettingsUpgradeable.proposalThreshold();
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC721ReceiverUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
        
    }

    
}
