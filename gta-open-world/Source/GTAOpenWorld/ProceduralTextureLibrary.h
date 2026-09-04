#pragma once

#include "CoreMinimal.h"

class UTexture2D;

// Builds small runtime UTexture2D assets purely from pixel math - no imported image
// files anywhere in this project. Feed the result into a UMaterialInstanceDynamic's
// "BaseTexture" parameter (see the M_Procedural setup step in README.md).
namespace ProceduralTextureLibrary
{
	UTexture2D* CreateSolidColorTexture(const FColor& Color, int32 Size = 4);
	UTexture2D* CreateNoiseTexture(const FColor& BaseColor, float Variation, int32 Size = 256, int32 Seed = 0);
	UTexture2D* CreateAsphaltTexture(int32 Size = 512, int32 Seed = 0);
	UTexture2D* CreateFacadeTexture(int32 Floors, int32 WindowsPerFloor, const FColor& WallColor, int32 Seed, int32 Size = 512);
	UTexture2D* CreateGroundTexture(int32 Size = 512, int32 Seed = 0);
}
