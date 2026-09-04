using UnrealBuildTool;
using System.Collections.Generic;

public class GTAOpenWorldEditorTarget : TargetRules
{
	public GTAOpenWorldEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V5;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_3;
		ExtraModuleNames.Add("GTAOpenWorld");
	}
}
