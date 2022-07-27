// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IAssetBox {
    function getbalance(uint8 roleIndex, uint256 tokenID)
        external
        view
        returns (uint256);

    function mint(
        uint8 roleIndex,
        uint256 tokenID,
        uint256 amount
    ) external;

    function transfer(
        uint8 roleIndex,
        uint256 from,
        uint256 to,
        uint256 amount
    ) external;

    function burn(
        uint8 roleIndex,
        uint256 tokenID,
        uint256 amount
    ) external;

    function getRole(uint8 index) external view returns (address);
}

contract GuildNFT is ERC721 {
    struct Guild {
        string name;
        string desc;
        string ipfsURI;
        uint256 president;
        uint256 level;
        ERC721 collection;
    }

    mapping(uint256 => Guild) public guilds;

    // collection => tokenId => guildId
    mapping(ERC721 => mapping(uint256 => uint256)) isMemberOf;
    // collection => tokenId => guildId => boolean
    mapping(ERC721 => mapping(uint256 => mapping(uint256 => bool))) appliedFor;

    mapping(uint256 => uint256) public maxMembers;
    mapping(uint256 => uint256) public membersAmount;
    // guildId => tokenId => boolean
    // mapping(uint256 => mapping(uint256 => bool)) public members;

    mapping(uint256 => uint256) public maxVicePresidents;
    mapping(uint256 => uint256) public vicePresidentAmount;
    // guildId => tokenId => boolean
    mapping(uint256 => mapping(uint256 => bool)) public vicePresidents;

    uint256 public next_;

    address public immutable copper;
    uint256 public immutable modifyNameAndIPFSCopperRequired;

    constructor(address copper_, uint256 modifyNameAndIPFSCopperRequired_)
        ERC721("Monster Guild", "MGUID")
    {
        copper = copper_;
        modifyNameAndIPFSCopperRequired = modifyNameAndIPFSCopperRequired_;
    }

    modifier is_president(uint256 guildId, uint256 tokenId) {
        Guild memory guild = guilds[guildId];
        require(
            _isApprovedOrOwner(guild.collection, msg.sender, tokenId),
            "Not approved or owner"
        );
        require(guild.president == tokenId, "Only president");
        _;
    }

    modifier is_or_vice_president(uint256 guildId, uint256 tokenId) {
        Guild memory guild = guilds[guildId];
        require(
            _isApprovedOrOwner(guild.collection, msg.sender, tokenId),
            "Not approved or owner"
        );
        if (guild.president != tokenId) {
            require(
                vicePresidents[guildId][tokenId],
                "Only president or vice-president"
            );
        }
        _;
    }

    function mint(
        ERC721 collection,
        uint256 preid,
        string memory name,
        string memory desc,
        string memory ipfsURI
    ) external {
        require(isMemberOf[collection][preid] == 0, "Joind a guild");
        require(validate_text(name, 2, 12), "Invalid name");
        require(validate_text(desc, 5, 100), "Invalid intro");
        require(bytes(ipfsURI).length < 100, "Invalid ipfsURI");

        require(
            _isApprovedOrOwner(collection, msg.sender, preid),
            "Not approved or owner"
        );

        next_++;

        uint256 level = 1;
        Guild memory guild = Guild(
            name,
            desc,
            ipfsURI,
            preid,
            level,
            collection
        );
        guilds[next_] = guild;

        change_limit(next_, level);

        isMemberOf[collection][preid] = next_;
        membersAmount[next_] += 1;

        _safeMint(msg.sender, next_);
    }

    function modify_name(
        uint256 guildId,
        uint256 preid,
        string memory name
    ) external is_president(guildId, preid) {
        require(validate_text(name, 2, 12), "Invalid name");

        IAssetBox(copper).burn(4, guildId, modifyNameAndIPFSCopperRequired);

        Guild storage guild = guilds[guildId];
        guild.name = name;
    }

    function modify_desc(
        uint256 guildId,
        uint256 preid,
        string memory desc
    ) external is_president(guildId, preid) {
        require(validate_text(desc, 5, 100), "Invalid intro");
        Guild storage guild = guilds[guildId];
        guild.desc = desc;
    }

    function modify_ipfsURI(
        uint256 guildId,
        uint256 preid,
        string memory ipfsURI
    ) external is_president(guildId, preid) {
        require(bytes(ipfsURI).length < 100, "Invalid ipfsURI");

        IAssetBox(copper).burn(4, guildId, modifyNameAndIPFSCopperRequired);

        Guild storage guild = guilds[guildId];
        guild.ipfsURI = ipfsURI;
    }

    function validate_text(
        string memory str,
        uint256 min,
        uint256 max
    ) public pure returns (bool) {
        bytes memory b = bytes(str);
        //between min & max char, not starting or ending by space
        if (
            b.length < min ||
            b.length > max ||
            b[0] == 0x20 ||
            b[b.length - 1] == 0x20
        ) return false;

        bytes1 last_char = b[0];

        for (uint256 i; i < b.length; i++) {
            bytes1 char = b[i];

            // Cannot contain continous spaces
            if (char == 0x20 && last_char == 0x20) return false;

            last_char = char;
        }

        return true;
    }

    function change_limit(uint256 guildId, uint256 level) private {
        uint256 membersLimit = member_limit(level);
        maxMembers[guildId] = membersLimit;
        maxVicePresidents[guildId] = membersLimit / 20;
    }

    function transfer_of_president(
        uint256 guildId,
        uint256 oriPreid,
        uint256 toPreid
    ) external is_president(guildId, oriPreid) {
        Guild storage guild = guilds[guildId];
        require(
            _isApprovedOrOwner(guild.collection, msg.sender, toPreid),
            "Not approved or owner"
        );
        require(isMemberOf[guild.collection][toPreid] == guildId);

        guild.president = toPreid;
    }

    function grant_vice_president(
        uint256 guildId,
        uint256 preid,
        uint256 vpreid
    ) external is_president(guildId, preid) {
        Guild memory guild = guilds[guildId];
        require(isMemberOf[guild.collection][vpreid] == guildId);
        require(!vicePresidents[guildId][vpreid], "Already vice president");
        require(
            vicePresidentAmount[guildId] < maxVicePresidents[guildId],
            "Exceed the limit"
        );

        vicePresidents[guildId][vpreid] = true;
        vicePresidentAmount[guildId] += 1;
    }

    function degrant_vice_president(
        uint256 guildId,
        uint256 preid,
        uint256 vpreid
    ) external is_president(guildId, preid) {
        require(vicePresidents[guildId][vpreid], "Not vice president");

        vicePresidents[guildId][vpreid] = false;
        vicePresidentAmount[guildId] -= 1;
    }

    function member_limit(uint256 current_level)
        public
        pure
        returns (uint256 membersLimit)
    {
        membersLimit = 50;
        uint256 base = 50;

        for (uint256 i = 1; i < current_level; i++) {
            base += 10 + 10 * i;
            membersLimit += base;
        }
    }

    function apply_for(uint256 guildId, uint256 tokenId) external {
        Guild memory guild = guilds[guildId];
        require(
            _isApprovedOrOwner(guild.collection, msg.sender, tokenId),
            "Not approved or owner"
        );
        require(
            isMemberOf[guild.collection][tokenId] == 0,
            "Already Joind a guild"
        );
        require(
            !appliedFor[guild.collection][tokenId][guildId],
            "Already applied "
        );
        require(membersAmount[guildId] < maxMembers[guildId], "Already full");

        appliedFor[guild.collection][tokenId][guildId] = true;
    }

    function _agree(uint256 guildId, uint256 member) private {
        Guild memory guild = guilds[guildId];
        require(appliedFor[guild.collection][member][guildId], "Not applied");
        require(isMemberOf[guild.collection][member] == 0, "Joind a guild");
        require(membersAmount[guildId] < maxMembers[guildId], "Already full");

        isMemberOf[guild.collection][member] = guildId;
        appliedFor[guild.collection][member][guildId] = false;
        membersAmount[guildId] += 1;
    }

    function batch_agree(
        uint256 guildId,
        uint256 tokenId,
        uint256[] calldata _members
    ) external is_or_vice_president(guildId, tokenId) {
        for (uint256 i = 0; i < _members.length; i++) {
            _agree(guildId, _members[i]);
        }
    }

    function _disagree(uint256 guildId, uint256 member) private {
        Guild memory guild = guilds[guildId];
        require(appliedFor[guild.collection][member][guildId], "Not applied");

        appliedFor[guild.collection][member][guildId] = false;
    }

    function batch_disagree(
        uint256 guildId,
        uint256 tokenId,
        uint256[] calldata _members
    ) external is_or_vice_president(guildId, tokenId) {
        for (uint256 i = 0; i < _members.length; i++) {
            _disagree(guildId, _members[i]);
        }
    }

    function _kick_out(
        uint256 guildId,
        uint256 tokenId,
        uint256 member
    ) private {
        Guild memory guild = guilds[guildId];

        require(
            isMemberOf[guild.collection][member] == guildId,
            "Not that guild member"
        );
        require(guild.president != member, "Can't kick president");

        if (guild.president != tokenId) {
            require(
                !vicePresidents[guildId][member],
                "Can't kick vice president"
            );
        }

        if (vicePresidents[guildId][member]) {
            vicePresidents[guildId][member] = false;
            vicePresidentAmount[guildId] -= 1;
        }

        isMemberOf[guild.collection][member] = 0;
        membersAmount[guildId] -= 1;
    }

    function batch_kick_out(
        uint256 guildId,
        uint256 tokenId,
        uint256[] calldata _members
    ) external is_or_vice_president(guildId, tokenId) {
        for (uint256 i = 0; i < _members.length; i++) {
            require(tokenId != _members[i], "Can't kick yourself");

            _kick_out(guildId, tokenId, _members[i]);
        }
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        Guild memory guild = guilds[_tokenId];

        string memory baseURI = guild.ipfsURI;
        return baseURI;
    }

    function _isApprovedOrOwner(
        ERC721 role,
        address operator,
        uint256 tokenId
    ) private view returns (bool) {
        address TokenOwner = role.ownerOf(tokenId);

        return (operator == TokenOwner ||
            IERC721(role).getApproved(tokenId) == operator ||
            IERC721(role).isApprovedForAll(TokenOwner, operator));
    }
}
