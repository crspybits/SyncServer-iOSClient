///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

import Foundation

/// Datatypes and serializers for the team_policies namespace
open class TeamPolicies {
    /// The EmmState union
    public enum EmmState: CustomStringConvertible {
        /// Emm token is disabled.
        case disabled
        /// Emm token is optional.
        case optional
        /// Emm token is required.
        case required
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(EmmStateSerializer().serialize(self)))"
        }
    }
    open class EmmStateSerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: EmmState) -> JSON {
            switch value {
                case .disabled:
                    var d = [String: JSON]()
                    d[".tag"] = .str("disabled")
                    return .dictionary(d)
                case .optional:
                    var d = [String: JSON]()
                    d[".tag"] = .str("optional")
                    return .dictionary(d)
                case .required:
                    var d = [String: JSON]()
                    d[".tag"] = .str("required")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> EmmState {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "disabled":
                            return EmmState.disabled
                        case "optional":
                            return EmmState.optional
                        case "required":
                            return EmmState.required
                        case "other":
                            return EmmState.other
                        default:
                            return EmmState.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// The GroupCreation union
    public enum GroupCreation: CustomStringConvertible {
        /// Team admins and members can create groups.
        case adminsAndMembers
        /// Only team admins can create groups.
        case adminsOnly

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(GroupCreationSerializer().serialize(self)))"
        }
    }
    open class GroupCreationSerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: GroupCreation) -> JSON {
            switch value {
                case .adminsAndMembers:
                    var d = [String: JSON]()
                    d[".tag"] = .str("admins_and_members")
                    return .dictionary(d)
                case .adminsOnly:
                    var d = [String: JSON]()
                    d[".tag"] = .str("admins_only")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> GroupCreation {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "admins_and_members":
                            return GroupCreation.adminsAndMembers
                        case "admins_only":
                            return GroupCreation.adminsOnly
                        default:
                            fatalError("Unknown tag \(tag)")
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// The OfficeAddInPolicy union
    public enum OfficeAddInPolicy: CustomStringConvertible {
        /// Office Add-In is disabled.
        case disabled
        /// Office Add-In is enabled.
        case enabled
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(OfficeAddInPolicySerializer().serialize(self)))"
        }
    }
    open class OfficeAddInPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: OfficeAddInPolicy) -> JSON {
            switch value {
                case .disabled:
                    var d = [String: JSON]()
                    d[".tag"] = .str("disabled")
                    return .dictionary(d)
                case .enabled:
                    var d = [String: JSON]()
                    d[".tag"] = .str("enabled")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> OfficeAddInPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "disabled":
                            return OfficeAddInPolicy.disabled
                        case "enabled":
                            return OfficeAddInPolicy.enabled
                        case "other":
                            return OfficeAddInPolicy.other
                        default:
                            return OfficeAddInPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// The PaperDeploymentPolicy union
    public enum PaperDeploymentPolicy: CustomStringConvertible {
        /// All team members have access to Paper.
        case full
        /// Only whitelisted team members can access Paper. To see which user is whitelisted, check
        /// 'is_paper_whitelisted' on 'account/info'.
        case partial
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(PaperDeploymentPolicySerializer().serialize(self)))"
        }
    }
    open class PaperDeploymentPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: PaperDeploymentPolicy) -> JSON {
            switch value {
                case .full:
                    var d = [String: JSON]()
                    d[".tag"] = .str("full")
                    return .dictionary(d)
                case .partial:
                    var d = [String: JSON]()
                    d[".tag"] = .str("partial")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> PaperDeploymentPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "full":
                            return PaperDeploymentPolicy.full
                        case "partial":
                            return PaperDeploymentPolicy.partial
                        case "other":
                            return PaperDeploymentPolicy.other
                        default:
                            return PaperDeploymentPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// The PaperEnabledPolicy union
    public enum PaperEnabledPolicy: CustomStringConvertible {
        /// Paper is disabled.
        case disabled
        /// Paper is enabled.
        case enabled
        /// Unspecified policy.
        case unspecified
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(PaperEnabledPolicySerializer().serialize(self)))"
        }
    }
    open class PaperEnabledPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: PaperEnabledPolicy) -> JSON {
            switch value {
                case .disabled:
                    var d = [String: JSON]()
                    d[".tag"] = .str("disabled")
                    return .dictionary(d)
                case .enabled:
                    var d = [String: JSON]()
                    d[".tag"] = .str("enabled")
                    return .dictionary(d)
                case .unspecified:
                    var d = [String: JSON]()
                    d[".tag"] = .str("unspecified")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> PaperEnabledPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "disabled":
                            return PaperEnabledPolicy.disabled
                        case "enabled":
                            return PaperEnabledPolicy.enabled
                        case "unspecified":
                            return PaperEnabledPolicy.unspecified
                        case "other":
                            return PaperEnabledPolicy.other
                        default:
                            return PaperEnabledPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// The PasswordStrengthPolicy union
    public enum PasswordStrengthPolicy: CustomStringConvertible {
        /// User passwords will adhere to the minimal password strength policy.
        case minimalRequirements
        /// User passwords will adhere to the moderate password strength policy.
        case moderatePassword
        /// User passwords will adhere to the very strong password strength policy.
        case strongPassword
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(PasswordStrengthPolicySerializer().serialize(self)))"
        }
    }
    open class PasswordStrengthPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: PasswordStrengthPolicy) -> JSON {
            switch value {
                case .minimalRequirements:
                    var d = [String: JSON]()
                    d[".tag"] = .str("minimal_requirements")
                    return .dictionary(d)
                case .moderatePassword:
                    var d = [String: JSON]()
                    d[".tag"] = .str("moderate_password")
                    return .dictionary(d)
                case .strongPassword:
                    var d = [String: JSON]()
                    d[".tag"] = .str("strong_password")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> PasswordStrengthPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "minimal_requirements":
                            return PasswordStrengthPolicy.minimalRequirements
                        case "moderate_password":
                            return PasswordStrengthPolicy.moderatePassword
                        case "strong_password":
                            return PasswordStrengthPolicy.strongPassword
                        case "other":
                            return PasswordStrengthPolicy.other
                        default:
                            return PasswordStrengthPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// The RolloutMethod union
    public enum RolloutMethod: CustomStringConvertible {
        /// Unlink all.
        case unlinkAll
        /// Unlink devices with the most inactivity.
        case unlinkMostInactive
        /// Add member to Exceptions.
        case addMemberToExceptions

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(RolloutMethodSerializer().serialize(self)))"
        }
    }
    open class RolloutMethodSerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: RolloutMethod) -> JSON {
            switch value {
                case .unlinkAll:
                    var d = [String: JSON]()
                    d[".tag"] = .str("unlink_all")
                    return .dictionary(d)
                case .unlinkMostInactive:
                    var d = [String: JSON]()
                    d[".tag"] = .str("unlink_most_inactive")
                    return .dictionary(d)
                case .addMemberToExceptions:
                    var d = [String: JSON]()
                    d[".tag"] = .str("add_member_to_exceptions")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> RolloutMethod {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "unlink_all":
                            return RolloutMethod.unlinkAll
                        case "unlink_most_inactive":
                            return RolloutMethod.unlinkMostInactive
                        case "add_member_to_exceptions":
                            return RolloutMethod.addMemberToExceptions
                        default:
                            fatalError("Unknown tag \(tag)")
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// Policy governing which shared folders a team member can join.
    public enum SharedFolderJoinPolicy: CustomStringConvertible {
        /// Team members can only join folders shared by teammates.
        case fromTeamOnly
        /// Team members can join any shared folder, including those shared by users outside the team.
        case fromAnyone
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(SharedFolderJoinPolicySerializer().serialize(self)))"
        }
    }
    open class SharedFolderJoinPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: SharedFolderJoinPolicy) -> JSON {
            switch value {
                case .fromTeamOnly:
                    var d = [String: JSON]()
                    d[".tag"] = .str("from_team_only")
                    return .dictionary(d)
                case .fromAnyone:
                    var d = [String: JSON]()
                    d[".tag"] = .str("from_anyone")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> SharedFolderJoinPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "from_team_only":
                            return SharedFolderJoinPolicy.fromTeamOnly
                        case "from_anyone":
                            return SharedFolderJoinPolicy.fromAnyone
                        case "other":
                            return SharedFolderJoinPolicy.other
                        default:
                            return SharedFolderJoinPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// Policy governing who can be a member of a folder shared by a team member.
    public enum SharedFolderMemberPolicy: CustomStringConvertible {
        /// Only a teammate can be a member of a folder shared by a team member.
        case team
        /// Anyone can be a member of a folder shared by a team member.
        case anyone
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(SharedFolderMemberPolicySerializer().serialize(self)))"
        }
    }
    open class SharedFolderMemberPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: SharedFolderMemberPolicy) -> JSON {
            switch value {
                case .team:
                    var d = [String: JSON]()
                    d[".tag"] = .str("team")
                    return .dictionary(d)
                case .anyone:
                    var d = [String: JSON]()
                    d[".tag"] = .str("anyone")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> SharedFolderMemberPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "team":
                            return SharedFolderMemberPolicy.team
                        case "anyone":
                            return SharedFolderMemberPolicy.anyone
                        case "other":
                            return SharedFolderMemberPolicy.other
                        default:
                            return SharedFolderMemberPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// Policy governing the visibility of shared links. This policy can apply to newly created shared links, or all
    /// shared links.
    public enum SharedLinkCreatePolicy: CustomStringConvertible {
        /// By default, anyone can access newly created shared links. No login will be required to access the shared
        /// links unless overridden.
        case defaultPublic
        /// By default, only members of the same team can access newly created shared links. Login will be required to
        /// access the shared links unless overridden.
        case defaultTeamOnly
        /// Only members of the same team can access all shared links. Login will be required to access all shared
        /// links.
        case teamOnly
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(SharedLinkCreatePolicySerializer().serialize(self)))"
        }
    }
    open class SharedLinkCreatePolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: SharedLinkCreatePolicy) -> JSON {
            switch value {
                case .defaultPublic:
                    var d = [String: JSON]()
                    d[".tag"] = .str("default_public")
                    return .dictionary(d)
                case .defaultTeamOnly:
                    var d = [String: JSON]()
                    d[".tag"] = .str("default_team_only")
                    return .dictionary(d)
                case .teamOnly:
                    var d = [String: JSON]()
                    d[".tag"] = .str("team_only")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> SharedLinkCreatePolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "default_public":
                            return SharedLinkCreatePolicy.defaultPublic
                        case "default_team_only":
                            return SharedLinkCreatePolicy.defaultTeamOnly
                        case "team_only":
                            return SharedLinkCreatePolicy.teamOnly
                        case "other":
                            return SharedLinkCreatePolicy.other
                        default:
                            return SharedLinkCreatePolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// The SmartSyncPolicy union
    public enum SmartSyncPolicy: CustomStringConvertible {
        /// The specified content will be synced as local files by default.
        case local
        /// The specified content will be synced as on-demand files by default.
        case onDemand
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(SmartSyncPolicySerializer().serialize(self)))"
        }
    }
    open class SmartSyncPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: SmartSyncPolicy) -> JSON {
            switch value {
                case .local:
                    var d = [String: JSON]()
                    d[".tag"] = .str("local")
                    return .dictionary(d)
                case .onDemand:
                    var d = [String: JSON]()
                    d[".tag"] = .str("on_demand")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> SmartSyncPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "local":
                            return SmartSyncPolicy.local
                        case "on_demand":
                            return SmartSyncPolicy.onDemand
                        case "other":
                            return SmartSyncPolicy.other
                        default:
                            return SmartSyncPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// The SsoPolicy union
    public enum SsoPolicy: CustomStringConvertible {
        /// Users will be able to sign in with their Dropbox credentials.
        case disabled
        /// Users will be able to sign in with either their Dropbox or single sign-on credentials.
        case optional
        /// Users will be required to sign in with their single sign-on credentials.
        case required
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(SsoPolicySerializer().serialize(self)))"
        }
    }
    open class SsoPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: SsoPolicy) -> JSON {
            switch value {
                case .disabled:
                    var d = [String: JSON]()
                    d[".tag"] = .str("disabled")
                    return .dictionary(d)
                case .optional:
                    var d = [String: JSON]()
                    d[".tag"] = .str("optional")
                    return .dictionary(d)
                case .required:
                    var d = [String: JSON]()
                    d[".tag"] = .str("required")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> SsoPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "disabled":
                            return SsoPolicy.disabled
                        case "optional":
                            return SsoPolicy.optional
                        case "required":
                            return SsoPolicy.required
                        case "other":
                            return SsoPolicy.other
                        default:
                            return SsoPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

    /// Policies governing team members.
    open class TeamMemberPolicies: CustomStringConvertible {
        /// Policies governing sharing.
        open let sharing: TeamPolicies.TeamSharingPolicies
        /// This describes the Enterprise Mobility Management (EMM) state for this team. This information can be used to
        /// understand if an organization is integrating with a third-party EMM vendor to further manage and apply
        /// restrictions upon the team's Dropbox usage on mobile devices. This is a new feature and in the future we'll
        /// be adding more new fields and additional documentation.
        open let emmState: TeamPolicies.EmmState
        /// The admin policy around the Dropbox Office Add-In for this team.
        open let officeAddin: TeamPolicies.OfficeAddInPolicy
        public init(sharing: TeamPolicies.TeamSharingPolicies, emmState: TeamPolicies.EmmState, officeAddin: TeamPolicies.OfficeAddInPolicy) {
            self.sharing = sharing
            self.emmState = emmState
            self.officeAddin = officeAddin
        }
        open var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(TeamMemberPoliciesSerializer().serialize(self)))"
        }
    }
    open class TeamMemberPoliciesSerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: TeamMemberPolicies) -> JSON {
            let output = [ 
            "sharing": TeamPolicies.TeamSharingPoliciesSerializer().serialize(value.sharing),
            "emm_state": TeamPolicies.EmmStateSerializer().serialize(value.emmState),
            "office_addin": TeamPolicies.OfficeAddInPolicySerializer().serialize(value.officeAddin),
            ]
            return .dictionary(output)
        }
        open func deserialize(_ json: JSON) -> TeamMemberPolicies {
            switch json {
                case .dictionary(let dict):
                    let sharing = TeamPolicies.TeamSharingPoliciesSerializer().deserialize(dict["sharing"] ?? .null)
                    let emmState = TeamPolicies.EmmStateSerializer().deserialize(dict["emm_state"] ?? .null)
                    let officeAddin = TeamPolicies.OfficeAddInPolicySerializer().deserialize(dict["office_addin"] ?? .null)
                    return TeamMemberPolicies(sharing: sharing, emmState: emmState, officeAddin: officeAddin)
                default:
                    fatalError("Type error deserializing")
            }
        }
    }

    /// Policies governing sharing within and outside of the team.
    open class TeamSharingPolicies: CustomStringConvertible {
        /// Who can join folders shared by team members.
        open let sharedFolderMemberPolicy: TeamPolicies.SharedFolderMemberPolicy
        /// Which shared folders team members can join.
        open let sharedFolderJoinPolicy: TeamPolicies.SharedFolderJoinPolicy
        /// Who can view shared links owned by team members.
        open let sharedLinkCreatePolicy: TeamPolicies.SharedLinkCreatePolicy
        public init(sharedFolderMemberPolicy: TeamPolicies.SharedFolderMemberPolicy, sharedFolderJoinPolicy: TeamPolicies.SharedFolderJoinPolicy, sharedLinkCreatePolicy: TeamPolicies.SharedLinkCreatePolicy) {
            self.sharedFolderMemberPolicy = sharedFolderMemberPolicy
            self.sharedFolderJoinPolicy = sharedFolderJoinPolicy
            self.sharedLinkCreatePolicy = sharedLinkCreatePolicy
        }
        open var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(TeamSharingPoliciesSerializer().serialize(self)))"
        }
    }
    open class TeamSharingPoliciesSerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: TeamSharingPolicies) -> JSON {
            let output = [ 
            "shared_folder_member_policy": TeamPolicies.SharedFolderMemberPolicySerializer().serialize(value.sharedFolderMemberPolicy),
            "shared_folder_join_policy": TeamPolicies.SharedFolderJoinPolicySerializer().serialize(value.sharedFolderJoinPolicy),
            "shared_link_create_policy": TeamPolicies.SharedLinkCreatePolicySerializer().serialize(value.sharedLinkCreatePolicy),
            ]
            return .dictionary(output)
        }
        open func deserialize(_ json: JSON) -> TeamSharingPolicies {
            switch json {
                case .dictionary(let dict):
                    let sharedFolderMemberPolicy = TeamPolicies.SharedFolderMemberPolicySerializer().deserialize(dict["shared_folder_member_policy"] ?? .null)
                    let sharedFolderJoinPolicy = TeamPolicies.SharedFolderJoinPolicySerializer().deserialize(dict["shared_folder_join_policy"] ?? .null)
                    let sharedLinkCreatePolicy = TeamPolicies.SharedLinkCreatePolicySerializer().deserialize(dict["shared_link_create_policy"] ?? .null)
                    return TeamSharingPolicies(sharedFolderMemberPolicy: sharedFolderMemberPolicy, sharedFolderJoinPolicy: sharedFolderJoinPolicy, sharedLinkCreatePolicy: sharedLinkCreatePolicy)
                default:
                    fatalError("Type error deserializing")
            }
        }
    }

    /// The TwoStepVerificationPolicy union
    public enum TwoStepVerificationPolicy: CustomStringConvertible {
        /// Enabled require two factor authorization.
        case requireTfaEnable
        /// Disabled require two factor authorization.
        case requireTfaDisable
        /// An unspecified error.
        case other

        public var description: String {
            return "\(SerializeUtil.prepareJSONForSerialization(TwoStepVerificationPolicySerializer().serialize(self)))"
        }
    }
    open class TwoStepVerificationPolicySerializer: JSONSerializer {
        public init() { }
        open func serialize(_ value: TwoStepVerificationPolicy) -> JSON {
            switch value {
                case .requireTfaEnable:
                    var d = [String: JSON]()
                    d[".tag"] = .str("require_tfa_enable")
                    return .dictionary(d)
                case .requireTfaDisable:
                    var d = [String: JSON]()
                    d[".tag"] = .str("require_tfa_disable")
                    return .dictionary(d)
                case .other:
                    var d = [String: JSON]()
                    d[".tag"] = .str("other")
                    return .dictionary(d)
            }
        }
        open func deserialize(_ json: JSON) -> TwoStepVerificationPolicy {
            switch json {
                case .dictionary(let d):
                    let tag = Serialization.getTag(d)
                    switch tag {
                        case "require_tfa_enable":
                            return TwoStepVerificationPolicy.requireTfaEnable
                        case "require_tfa_disable":
                            return TwoStepVerificationPolicy.requireTfaDisable
                        case "other":
                            return TwoStepVerificationPolicy.other
                        default:
                            return TwoStepVerificationPolicy.other
                    }
                default:
                    fatalError("Failed to deserialize")
            }
        }
    }

}
