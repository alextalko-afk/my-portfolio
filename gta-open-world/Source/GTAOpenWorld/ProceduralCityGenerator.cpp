#include "ProceduralCityGenerator.h"
#include "ProceduralTextureLibrary.h"
#include "Components/SceneComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Engine/Texture2D.h"
#include "Engine/Engine.h"

AProceduralCityGenerator::AProceduralCityGenerator()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

void AProceduralCityGenerator::BeginPlay()
{
	Super::BeginPlay();
}

void AProceduralCityGenerator::LoadBaseMaterial()
{
	BaseMaterial = LoadObject<UMaterialInterface>(nullptr, TEXT("/Game/Materials/M_Procedural.M_Procedural"));

	if (!BaseMaterial && GEngine)
	{
		GEngine->AddOnScreenDebugMessage(-1, 30.f, FColor::Red,
			TEXT("M_Procedural not found at /Game/Materials/M_Procedural - create it (README: 'One-time editor setup'). City will render with the default grey material until then."));
	}
}

UProceduralMeshComponent* AProceduralCityGenerator::CreateMeshComponent(const FString& Name)
{
	UProceduralMeshComponent* Mesh = NewObject<UProceduralMeshComponent>(this, *Name);
	Mesh->SetupAttachment(RootComponent);
	Mesh->RegisterComponent();
	// Movable: this geometry has no second (lightmap) UV channel, so Static mobility
	// would just warn about missing lightmap UVs. Fully dynamic lighting is the right
	// fit for runtime-generated content anyway.
	Mesh->SetMobility(EComponentMobility::Movable);
	SpawnedMeshes.Add(Mesh);
	return Mesh;
}

void AProceduralCityGenerator::FinalizeSection(UProceduralMeshComponent* Mesh, const FProcMeshData& MeshData, UTexture2D* Texture)
{
	if (!Mesh || MeshData.Vertices.Num() == 0)
	{
		return;
	}

	TArray<FLinearColor> EmptyColors;
	// NOTE: some UE5 versions only expose the 4-UV-channel overload of this function
	// (UV0, UV1, UV2, UV3). If this line fails to compile, pass MeshData.UVs for UV0
	// and empty TArray<FVector2D>{} for UV1-3 - this single-UV overload is the one
	// piece of the PMC API this project couldn't verify without a compiler.
	Mesh->CreateMeshSection_LinearColor(0, MeshData.Vertices, MeshData.Triangles, MeshData.Normals, MeshData.UVs, EmptyColors, MeshData.Tangents, true);

	if (BaseMaterial && Texture)
	{
		if (UMaterialInstanceDynamic* MID = UMaterialInstanceDynamic::Create(BaseMaterial, Mesh))
		{
			MID->SetTextureParameterValue(TEXT("BaseTexture"), Texture);
			Mesh->SetMaterial(0, MID);
		}
	}
}

void AProceduralCityGenerator::GenerateCity()
{
	LoadBaseMaterial();
	BuildGround();
	BuildRoadGrid();

	for (int32 y = 0; y < BlocksPerSide; ++y)
	{
		for (int32 x = 0; x < BlocksPerSide; ++x)
		{
			BuildBlock(x, y);
		}
	}
}

void AProceduralCityGenerator::BuildGround()
{
	const float Extent = GetCityExtent();
	FProcMeshData MeshData;
	ProceduralMeshUtils::AddGroundQuad(MeshData, FVector(Extent * 0.5f, Extent * 0.5f, -5.f), FVector2D(Extent * 0.5f + 2000.f, Extent * 0.5f + 2000.f), 8.f);

	UProceduralMeshComponent* Mesh = CreateMeshComponent(TEXT("Ground"));
	UTexture2D* Texture = ProceduralTextureLibrary::CreateGroundTexture(512, 1);
	FinalizeSection(Mesh, MeshData, Texture);
}

void AProceduralCityGenerator::BuildRoadGrid()
{
	const float Extent = GetCityExtent();
	UTexture2D* AsphaltTexture = ProceduralTextureLibrary::CreateAsphaltTexture(512, 2);

	FProcMeshData MeshData;
	for (int32 i = 0; i <= BlocksPerSide; ++i)
	{
		const float Offset = i * BlockSize;

		// Road running along X, centered at Y = Offset
		ProceduralMeshUtils::AddGroundQuad(MeshData, FVector(Extent * 0.5f, Offset, 0.f), FVector2D(Extent * 0.5f + RoadWidth, RoadWidth * 0.5f), 6.f);
		// Road running along Y, centered at X = Offset
		ProceduralMeshUtils::AddGroundQuad(MeshData, FVector(Offset, Extent * 0.5f, 1.f), FVector2D(RoadWidth * 0.5f, Extent * 0.5f + RoadWidth), 6.f);
	}

	UProceduralMeshComponent* Mesh = CreateMeshComponent(TEXT("Roads"));
	FinalizeSection(Mesh, MeshData, AsphaltTexture);
}

void AProceduralCityGenerator::BuildBlock(int32 BlockX, int32 BlockY)
{
	const float BlockOriginX = BlockX * BlockSize;
	const float BlockOriginY = BlockY * BlockSize;
	const float LotInset = RoadWidth * 0.5f + SidewalkWidth;
	const float LotSize = BlockSize - LotInset * 2.f;

	if (LotSize <= 200.f)
	{
		return;
	}

	const int32 Seed = BlockX * 9176 + BlockY * 5347 + 11;
	FRandomStream BlockStream(Seed);

	// Sidewalk: flat ring filling the block, slightly above road height
	FProcMeshData SidewalkData;
	ProceduralMeshUtils::AddGroundQuad(SidewalkData, FVector(BlockOriginX, BlockOriginY, 2.f), FVector2D(BlockSize * 0.5f - RoadWidth * 0.5f, BlockSize * 0.5f - RoadWidth * 0.5f), 4.f);
	UProceduralMeshComponent* SidewalkMesh = CreateMeshComponent(FString::Printf(TEXT("Sidewalk_%d_%d"), BlockX, BlockY));
	UTexture2D* SidewalkTexture = ProceduralTextureLibrary::CreateNoiseTexture(FColor(140, 138, 132, 255), 0.08f, 256, Seed + 1);
	FinalizeSection(SidewalkMesh, SidewalkData, SidewalkTexture);

	// Building footprint, randomized within the lot
	const float FootprintW = FMath::Max(LotSize * BlockStream.FRandRange(0.55f, 0.85f), 400.f);
	const float FootprintD = FMath::Max(LotSize * BlockStream.FRandRange(0.55f, 0.85f), 400.f);
	const int32 Floors = BlockStream.RandRange(MinFloors, MaxFloors);
	const float Height = Floors * FloorHeight;

	FProcMeshData BuildingData;
	ProceduralMeshUtils::AddBox(BuildingData, FVector(BlockOriginX, BlockOriginY, 10.f), FVector(FootprintW, FootprintD, Height), 1.f);

	UProceduralMeshComponent* BuildingMesh = CreateMeshComponent(FString::Printf(TEXT("Building_%d_%d"), BlockX, BlockY));

	static const TArray<FColor> WallPalette = {
		FColor(196, 184, 168, 255),
		FColor(150, 96, 78, 255),
		FColor(120, 128, 134, 255),
		FColor(178, 160, 120, 255),
		FColor(90, 100, 108, 255)
	};
	const FColor WallColor = WallPalette[BlockStream.RandRange(0, WallPalette.Num() - 1)];
	const int32 WindowsPerFloor = FMath::Clamp(FMath::RoundToInt(FootprintW / 250.f), 2, 10);

	UTexture2D* FacadeTexture = ProceduralTextureLibrary::CreateFacadeTexture(Floors, WindowsPerFloor, WallColor, Seed + 2, 512);
	FinalizeSection(BuildingMesh, BuildingData, FacadeTexture);
}
