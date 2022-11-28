// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./interfaces/IERC721Receiver.sol";
import "./tokens/ERC721.sol";
import "./tokens/ERC20.sol";
import "./utils/SafeMath.sol";

contract Market is IERC721Receiver {
    ERC20 public erc20;
    ERC721 public erc721;

    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    struct Order {
        address seller;
        uint256 tokenId;
        uint256 price;
    }

    mapping(uint256 => Order) public orderOfId; // token id to order
    Order[] public orders;
    mapping(uint256 => uint256) public idToOrderIndex;

    event Deal(address buyer, address seller, uint256 tokenId, uint256 price);
    event NewOrder(address seller, uint256 tokenId, uint256 price);
    event CancelOrder(address seller, uint256 tokenId);
    event ChangePrice(
        address seller,
        uint256 tokenId,
        uint256 previousPrice,
        uint256 price
    );

    constructor(ERC20 _erc20, ERC721 _erc721) {
        require(
            address(_erc20) != address(0),
            "Market: ERC20 contract address must be non-null"
        );
        require(
            address(_erc721) != address(0),
            "Market: ERC721 contract address must be non-null"
        );
        erc20 = _erc20;
        erc721 = _erc721;
    }

    function buy(uint256 _tokenId, uint256 _price) external {
        // 此处编写业务逻辑
        address buyer = msg.sender;
        Order memory targetOrder = orderOfId[_tokenId];
        uint price = targetOrder.price;
        address seller = targetOrder.seller;
        require(_price >= price, "price not enough");
        // ERC20打钱
        erc20.transferFrom(buyer, seller, _price);

        // ERC721转移给买家
        erc721.safeTransferFrom(address(this), buyer, _tokenId);

        // 下架 NFT
        removeListing(_tokenId);

        emit Deal(buyer, seller, _tokenId, price);
    }

    function cancelOrder(uint256 _tokenId) external {
        // 此处编写业务逻辑
        Order memory targetOrder = orderOfId[_tokenId];
        address seller = targetOrder.seller;
        require(msg.sender == seller, "Only seller can cancel order");
        removeListing(_tokenId);

        emit CancelOrder(seller, _tokenId);
    }

    function changePrice(uint256 _tokenId, uint256 _price) external {
        // 此处编写业务逻辑
        Order memory targetOrder = orderOfId[_tokenId];
        address seller = targetOrder.seller;
        require(seller == msg.sender, "only seller can change price");

        uint previousPrice = targetOrder.price;
        targetOrder.price = _price;

        emit ChangePrice(seller, _tokenId, previousPrice, _price);
    }

    function onERC721Received(
        address _operator,
        address _seller,
        uint256 _tokenId,
        bytes calldata _data
    ) public override returns (bytes4) {
        // 此处编写业务逻辑
        uint _price = toUint256(_data, 0);
        placeOrder(_seller, _tokenId, _price);

        return MAGIC_ON_ERC721_RECEIVED;
    }

    function isListed(uint256 _tokenId) public view returns (bool) {
        return orderOfId[_tokenId].seller != address(0);
    }

    function getOrderLength() public view returns (uint256) {
        return orders.length;
    }

    function placeOrder(
        address _seller,
        uint256 _tokenId,
        uint256 _price
    ) internal {
        // 此处编写业务逻辑
        Order memory newOrder = {_seller, _tokenId, _price};
        idToOrderIndex[_tokenId] = getOrderLength();

        orders.push(newOrder);
        orderOfId[_tokenId] = newOrder;

        emit NewOrder(_seller, _tokenId, _price);
    }

    function removeListing(uint256 _tokenId) internal {
        // 此处编写业务逻辑
        Order memory targetOrder = orderOfId[_tokenId];

        uint index = idToOrderIndex[_tokenId];
        Order memory lastOrder = orders[getOrderLength() - 1];
        orders[index] = lastOrder;
        orders.pop();

        orderOfId[_tokenId].seller = address(0);
    }

    // https://stackoverflow.com/questions/63252057/how-to-use-bytestouint-function-in-solidity-the-one-with-assembly
    function toUint256(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint256)
    {
        require(_start + 32 >= _start, "Market: toUint256_overflow");
        require(_bytes.length >= _start + 32, "Market: toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }
}
