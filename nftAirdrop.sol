// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFTAirdrop is IERC721Receiver, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address public allowedNFTContract;

    // Tracks inventory status and maintains a counter for NFTs held
    mapping(address => mapping(uint256 => bool)) public nftInventory;
    uint256 private nftCount;

    event NFTReceived(address indexed contractAddress, uint256 indexed tokenId, address indexed from);
    event NFTAirdropped(address indexed contractAddress, uint256 indexed tokenId, address indexed to);

    constructor(address _nftContract) {
        // Grant the default admin role to the deployer; this role can manage other roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Grant the custom admin role to the deployer
        _grantRole(ADMIN_ROLE, msg.sender);

        allowedNFTContract = _nftContract;
    }

    function onERC721Received(
        address /* operator */,    // This will comment out the parameter name
        address from,
        uint256 tokenId,
        bytes calldata /* data */  // This will comment out the parameter name
    ) external override returns (bytes4) {
        require(msg.sender == allowedNFTContract, "NFT contract not allowed.");
        nftInventory[msg.sender][tokenId] = true;
        nftCount++; // Increment the count of received NFTs

        emit NFTReceived(msg.sender, tokenId, from);
        return this.onERC721Received.selector;
    }

    // Function to receive multiple NFTs at once
    function bulkReceiveNFTs(uint256[] memory tokenIds) external {
        require(tokenIds.length > 0, "No token IDs provided");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            // Ensure that the sender is the owner of the token
            require(IERC721(allowedNFTContract).ownerOf(tokenId) == msg.sender, "Not the owner");

            // Transfer the token to this contract
            IERC721(allowedNFTContract).transferFrom(msg.sender, address(this), tokenId);
            
            // Mark the token in the contract inventory
            nftInventory[allowedNFTContract][tokenId] = true;
            nftCount++; // Increment the count

            // Emit an event logging the transfer
            emit NFTReceived(allowedNFTContract, tokenId, msg.sender);
        }
    }

    function bulkAirdropNFT(uint256[] memory tokenIds, address[] memory recipients) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(tokenIds.length == recipients.length, "Token and recipient arrays must be the same length");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(nftInventory[allowedNFTContract][tokenIds[i]], "Token is not in inventory");

            IERC721(allowedNFTContract).safeTransferFrom(address(this), recipients[i], tokenIds[i]);
            emit NFTAirdropped(allowedNFTContract, tokenIds[i], recipients[i]);

            nftInventory[allowedNFTContract][tokenIds[i]] = false;
            nftCount--; // Decrement the count when airdropped
        }
    }

    // Function to update the allowed NFT contract address, only callable by the owner
    function updateAllowedNFTContract(address newNFTContract) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a super admin");
        allowedNFTContract = newNFTContract;
    }

    // Function to get the total count of NFTs held by the contract
    function getTotalNFTs() public view returns (uint256) {
        return nftCount;
    }

    function addAdmin(address user) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a super admin");
        grantRole(ADMIN_ROLE, user);
    }

    function revokeAdmin(address user) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a super admin");
        revokeRole(ADMIN_ROLE, user);
    }
}
