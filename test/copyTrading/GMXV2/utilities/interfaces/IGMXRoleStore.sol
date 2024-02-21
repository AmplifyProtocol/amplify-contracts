// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

interface IGMXRoleStore {
    /**
     * @dev Returns the number of members of the specified role.
     *
     * @param roleKey The key of the role.
     * @return The number of members of the role.
     */
    function getRoleMemberCount(bytes32 roleKey) external view returns (uint256);

    /**
     * @dev Returns the members of the specified role.
     *
     * @param roleKey The key of the role.
     * @param start the start index, the value for this index will be included.
     * @param end the end index, the value for this index will not be included.
     * @return The members of the role.
     */
    function getRoleMembers(bytes32 roleKey, uint256 start, uint256 end) external view returns (address[] memory);
}