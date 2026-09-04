#pragma once

#include "CoreMinimal.h"
#include "ProceduralMeshComponent.h"

// Pure geometry helpers that append triangles to a mesh-section buffer, ready to hand
// to UProceduralMeshComponent::CreateMeshSection_LinearColor(). No imported meshes
// anywhere in this project - every shape (buildings, roads, car body, character
// block-out) is built from these at runtime, the same way aim-trainer's level
// geometry is all procedural GDScript.
struct FProcMeshData
{
	TArray<FVector> Vertices;
	TArray<int32> Triangles;
	TArray<FVector> Normals;
	TArray<FVector2D> UVs;
	TArray<FProcMeshTangent> Tangents;

	void Reset()
	{
		Vertices.Reset();
		Triangles.Reset();
		Normals.Reset();
		UVs.Reset();
		Tangents.Reset();
	}
};

namespace ProceduralMeshUtils
{
	// Appends a closed box. BottomCenter is the world-space center of the box's
	// bottom face; Size is full width(X)/depth(Y)/height(Z). UVTiling controls how
	// many texture repeats appear per 100 units of surface (1 = one full facade
	// texture per meter-ish face).
	void AddBox(FProcMeshData& MeshData, const FVector& BottomCenter, const FVector& Size, float UVTiling = 1.f);

	// Appends a flat, upward-facing quad. Origin is its world-space center; HalfSize
	// is the half-extent along X/Y. Used for ground, roads, sidewalks.
	void AddGroundQuad(FProcMeshData& MeshData, const FVector& Origin, const FVector2D& HalfSize, float UVTiling = 1.f);

	// Appends a single vertical quad facing FacingNormal, useful for curbs and thin
	// walls where a full box would be wasted geometry.
	void AddVerticalQuad(FProcMeshData& MeshData, const FVector& BottomCenter, float Width, float Height, const FVector& FacingNormal, float UVTiling = 1.f);
}
