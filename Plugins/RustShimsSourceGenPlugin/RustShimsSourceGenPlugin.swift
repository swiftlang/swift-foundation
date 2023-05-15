import PackagePlugin

@main
struct SwiftGenPlugin: BuildToolPlugin {
    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        
        //let inputJSON = target.directory.appending("Source.json")
        //let output = target.directory.appending("GeneratedEnum.swift")//context.pluginWorkDirectory.appending("GeneratedEnum.swift")
        return [
            .prebuildCommand(displayName: "Generate static Lib",
                          executable: target.directory.appending("build.sh"),//Path("/usr/bin/make"),//.init("/usr/bin/make"), //try context.tool(named: "/usr/bin/make").path,
                          arguments: [target.directory],
                          environment: [:],
                          outputFilesDirectory: target.directory)
        ]
    }
}
