// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./interfaces/IBEP20.sol";
import "./libraries/ReentrancyGuard.sol";

contract Presale is ReentrancyGuard {
    address public owner;
    uint256 public maxContribution = 5 ether;
    uint256 public startTime = block.timestamp;
    uint256 public endTime;
    uint256 public tokenPrice; // Price in wei per token
    uint256 public totalRaised;
    uint256 public participantCount;
    bool public finalized;

    IBEP20 public token;

    mapping(address => uint256) public contributions;
    mapping(address => bool) private hasParticipated;
    mapping(bytes32 => uint256) public referralContributions;
    mapping(bytes32 => address) public referralOwners; // Tracks the owner of each referral code
    mapping(bytes32 => uint256) public referralUserCount; // Tracks the number of users referred by each referral code


    // Custom Errors
    error NotContractOwner();
    error SaleNotActive();
    error SaleEnded();
    error ContributionTooLow();
    error ContributionExceedsLimit();
    error InvalidRecipient();
    error RecipientInterfaceNotSupported();
    error CannotUseOwnReferralCode();

    event Contribution(address indexed contributor, uint256 amount, bytes32 referralCode);
    event Finalized(uint256 totalRaised);
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotContractOwner();
        _;
    }

    modifier onlyDuringSale() {
        if (block.timestamp < startTime) revert SaleNotActive();
        if (block.timestamp > endTime) revert SaleEnded();
        _;
    }

    modifier onlyAfterSale() {
        if (!finalized) {
            if (block.timestamp <= endTime) revert SaleNotActive();
        }
        _;
    }

    constructor(
        address _tokenAddress, 
        uint256 _tokenPrice, 
        uint256 _endTime
    ) {
        owner = msg.sender;
        tokenPrice = _tokenPrice;
        endTime = _endTime;
        token = IBEP20(_tokenAddress);
    }

    function contribute(bytes32 referralCode) external payable onlyDuringSale {
        if (msg.value > maxContribution) revert ContributionExceedsLimit();
        if (contributions[msg.sender] > 0) revert("Already contributed");

        // Check if the user is using their own referral code
        if (referralCode != bytes32(0)) {
            address referrer = referralOwners[referralCode];
            if (referrer == msg.sender) {
                revert CannotUseOwnReferralCode();
            }

            // Track referral contributions
            referralContributions[referralCode] += msg.value;
            referralUserCount[referralCode] += 1;
        }

        // Mark the sender as a participant
        hasParticipated[msg.sender] = true;
        participantCount += 1;

        // Update the contributions mapping and total raised
        contributions[msg.sender] = msg.value;
        totalRaised += msg.value;

        // Calculate the token amount and mint to the contributor
        uint256 tokenAmount = (msg.value * 1e18) / tokenPrice;
        token.transfer(msg.sender, tokenAmount);

        emit Contribution(msg.sender, msg.value, referralCode);
    }
    
    function getTotalReferredByCode(bytes32 referralCode) external view returns (uint256) {
        return referralContributions[referralCode];
    }

    function getReferralUserCount(bytes32 referralCode) external view returns (uint256) {
        return referralUserCount[referralCode];
    }

    function finalize() public onlyOwner {
        if (block.timestamp <= endTime) revert SaleNotActive();
        finalized = true;
        emit Finalized(totalRaised);
    }

    function withdrawFunds(address recipient) external onlyOwner nonReentrant onlyAfterSale {
        if (recipient == address(0)) revert InvalidRecipient();

        uint256 balance = address(this).balance;
        payable(recipient).transfer(balance);
        emit FundsWithdrawn(recipient, balance);
    }
    
    function recoverTokens(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        IBEP20 recoverToken = IBEP20(tokenAddress);
        recoverToken.transfer(owner, recoverToken.balanceOf(address(this)));
    }

    function setTokenPrice(uint256 _tokenPrice) external onlyOwner {
        tokenPrice = _tokenPrice;
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        endTime = _endTime;
    }

    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }

    function getParticipantCount() external view returns (uint256) {
        return participantCount;
    }

    function getTotalRaised() external view returns (uint256) {
        return totalRaised;
    }

    function getContribution(address participant) external view returns (uint256) {
        return contributions[participant];
    }
    
}
