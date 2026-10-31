import Vapor

/// Name of the Vapor command that applies migrations; the only command that
/// uses `configureMigrator` instead of `configure`.
let migrateCommandName = "migrate"

/// Operator command that creates the owner account; uses `configureOwnerCommand`.
let createOwnerCommandName = "create-owner"

/// The command Vapor will run for `arguments` (the executable path first), or
/// nil when none is named, in which case Vapor runs its default, `serve`.
///
/// ConsoleKit resolves the command as the first argument that does not start
/// with `-` (`CommandInput.nextArgument`, internal to the library, so repeated
/// here). Using the same rule means `App --env staging migrate` and
/// `App migrate --yes` select the same mode here and in Vapor. Pass
/// `Environment.arguments`, where Vapor has already removed `--env` and `--log`.
func requestedCommand(in arguments: [String]) -> String? {
    arguments.dropFirst().first { !$0.hasPrefix("-") }
}
