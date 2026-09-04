#include "GTAOpenWorldGameMode.h"
#include "OpenWorldCharacter.h"
#include "OpenWorldPlayerController.h"
#include "ArcadeVehicle.h"
#include "ProceduralCityGenerator.h"
#include "DayNightCycle.h"

AGTAOpenWorldGameMode::AGTAOpenWorldGameMode()
{
	DefaultPawnClass = AOpenWorldCharacter::StaticClass();
	PlayerControllerClass = AOpenWorldPlayerController::StaticClass();
}

void AGTAOpenWorldGameMode::BeginPlay()
{
	Super::BeginPlay();

	if (bWorldBuilt)
	{
		return;
	}
	bWorldBuilt = true;

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	CityGenerator = GetWorld()->SpawnActor<AProceduralCityGenerator>(AProceduralCityGenerator::StaticClass(), FTransform::Identity, Params);
	if (CityGenerator)
	{
		CityGenerator->BlocksPerSide = CityBlocksPerSide;
		CityGenerator->BlockSize = BlockSize;
		CityGenerator->GenerateCity();
	}

	DayNight = GetWorld()->SpawnActor<ADayNightCycle>(ADayNightCycle::StaticClass(), FTransform::Identity, Params);

	SpawnStarterVehicle();
}

void AGTAOpenWorldGameMode::SpawnStarterVehicle()
{
	const float Center = (CityBlocksPerSide * BlockSize) * 0.5f;
	const FVector SpawnLocation(Center + 400.f, Center + 400.f, 150.f);

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;
	GetWorld()->SpawnActor<AArcadeVehicle>(AArcadeVehicle::StaticClass(), FTransform(FRotator::ZeroRotator, SpawnLocation), Params);
}

void AGTAOpenWorldGameMode::RestartPlayer(AController* NewPlayer)
{
	Super::RestartPlayer(NewPlayer);

	if (NewPlayer && NewPlayer->GetPawn())
	{
		const float Center = (CityBlocksPerSide * BlockSize) * 0.5f;
		NewPlayer->GetPawn()->SetActorLocation(FVector(Center, Center, 200.f));
	}
}
