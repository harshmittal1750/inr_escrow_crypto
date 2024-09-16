// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title EscrowContract
 * @dev An escrow smart contract for cryptocurrency transactions between a buyer and a seller.
 */
contract EscrowContract {
    address payable public buyer;
    address payable public seller;
    address public escrowAgent;
    uint256 public amount;
    bool public sellerDeposited;
    bool public buyerVerified;
    bool public sellerVerified;
    bool public inrReceived;
    bool public fundsReleased;

    enum State { AWAITING_VERIFICATION, AWAITING_DEPOSIT, AWAITING_PAYMENT, AWAITING_CONFIRMATION, COMPLETE }
    State public currentState;

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this method");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this method");
        _;
    }

    modifier onlyEscrowAgent() {
        require(msg.sender == escrowAgent, "Only escrow agent can call this method");
        _;
    }

    constructor(address payable _buyer, address payable _seller) {
        escrowAgent = msg.sender; // The deployer is the escrow agent
        buyer = _buyer;
        seller = _seller;
        currentState = State.AWAITING_VERIFICATION;
    }

    /**
     * @dev Buyer verifies their address by sending a small amount.
     */
    function buyerVerify() external payable onlyBuyer {
        require(currentState == State.AWAITING_VERIFICATION, "Wrong state");
        require(msg.value > 0, "Verification amount must be greater than zero");
        buyerVerified = true;
        _checkVerification();
    }

    /**
     * @dev Seller verifies their address by sending a small amount.
     */
    function sellerVerify() external payable onlySeller {
        require(currentState == State.AWAITING_VERIFICATION, "Wrong state");
        require(msg.value > 0, "Verification amount must be greater than zero");
        sellerVerified = true;
        _checkVerification();
    }

    /**
     * @dev Internal function to check if both parties have verified.
     */
    function _checkVerification() internal {
        if (buyerVerified && sellerVerified) {
            currentState = State.AWAITING_DEPOSIT;
        }
    }

    /**
     * @dev Seller deposits the cryptocurrency into the escrow contract.
     */
    function sellerDeposit() external payable onlySeller {
        require(currentState == State.AWAITING_DEPOSIT, "Wrong state");
        require(msg.value > 0, "Deposit amount must be greater than zero");
        amount = msg.value;
        sellerDeposited = true;
        currentState = State.AWAITING_PAYMENT;
    }

    /**
     * @dev Seller confirms receipt of INR payment.
     */
    function confirmINRReceived() external onlySeller {
        require(currentState == State.AWAITING_PAYMENT, "Wrong state");
        inrReceived = true;
        currentState = State.AWAITING_CONFIRMATION;
    }

    /**
     * @dev Escrow agent releases funds to the buyer after seller confirms INR receipt.
     */
    function releaseFundsToBuyer() external onlyEscrowAgent {
        require(currentState == State.AWAITING_CONFIRMATION, "Wrong state");
        require(inrReceived, "INR not confirmed by seller");
        require(!fundsReleased, "Funds already released");

        buyer.transfer(amount);
        fundsReleased = true;
        currentState = State.COMPLETE;

        // Refund the verification amounts
        _refundVerificationAmounts();
    }

    /**
     * @dev Escrow agent refunds the seller in case of a cancellation.
     */
    function refundSeller() external onlyEscrowAgent {
        require(currentState != State.COMPLETE, "Transaction already complete");
        require(sellerDeposited, "Seller has not deposited funds");
        require(!fundsReleased, "Funds already released");

        seller.transfer(amount);
        fundsReleased = true;
        currentState = State.COMPLETE;

        // Refund the verification amounts
        _refundVerificationAmounts();
    }

    /**
     * @dev Internal function to refund verification amounts.
     */
    function _refundVerificationAmounts() internal {
        // Assuming the verification amounts are stored, refund them
        // For simplicity, we are not tracking the exact amounts
        // In a real contract, you should store and refund the exact amounts
        buyer.transfer(address(this).balance / 2);
        seller.transfer(address(this).balance);
    }
}
