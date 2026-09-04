#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ProceduralMeshUtils.h"
#include "ProceduralCityGenerator.generated.h"

class UProceduralMeshComponent;
class UMaterialInterface;
class UTexture2D;

// Builds an entire city grid - ground, road network, per-block sidewalks and
// buildings - from primitives and runtime textures. No level design, no imported
// meshes: call GenerateCity() once (GameMode does this on BeginPlay) and the whole
// world exists. Mirrors how aim-trainer's range_builder.gd builds its arena.
UCLASS()
class GTAOPENWORLD_API AProceduralCityGenerator : public AActor
{
	GENERATED_BODY()

public:
	AProceduralCityGenerator();

	UPROPERTY(EditAnywhere, Category = "City")
	int32 BlocksPerSide = 6;

	UPROPERTY(EditAnywhere, Category = "City")
	float BlockSize = 4000.f;

	UPROPERTY(EditAnywhere, Category = "City")
	float RoadWidth = 800.f;

	UPROPERTY(EditAnywhere, Category = "City")
	float SidewalkWidth = 150.f;

	UPROPERTY(EditAnywhere, Category = "City")
	int32 MinFloors = 2;

	UPROPERTY(EditAnywhere, Category = "City")
	int32 MaxFloors = 14;

	UPROPERTY(EditAnywhere, Category = "City")
	float FloorHeight = 340.f;

	// Builds the entire city. Call exactly once per spawned instance.
	void GenerateCity();

	float GetCityExtent() const { return BlocksPerSide * BlockSize; }

protected:
	virtual void BeginPlay() override;

private:
	UPROPERTY()
	TObjectPtr<UMaterialInterface> BaseMaterial;

	UPROPERTY()
	TArray<TObjectPtr<UProceduralMeshComponent>> SpawnedMeshes;

	void LoadBaseMaterial();
	void BuildGround();
	void BuildRoadGrid();
	void BuildBlock(int32 BlockX, int32 BlockY);

	UProceduralMeshComponent* CreateMeshComponent(const FString& Name);
	void FinalizeSection(UProceduralMeshComponent* Mesh, const FProcMeshData& MeshData, UTexture2D* Texture);
};
