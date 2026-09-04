#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "GTAOpenWorldGameMode.generated.h"

class AProceduralCityGenerator;
class ADayNightCycle;

// Wires the whole prototype together: spawns the city, the day/night cycle, and one
// parked car, then drops the player at the map center. Works on a completely empty
// level - nothing needs to be hand-placed (see README).
UCLASS()
class GTAOPENWORLD_API AGTAOpenWorldGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	AGTAOpenWorldGameMode();

protected:
	virtual void BeginPlay() override;
	virtual void RestartPlayer(AController* NewPlayer) override;

	UPROPERTY(EditDefaultsOnly, Category = "World")
	int32 CityBlocksPerSide = 6;

	UPROPERTY(EditDefaultsOnly, Category = "World")
	float BlockSize = 4000.f;

private:
	UPROPERTY()
	TObjectPtr<AProceduralCityGenerator> CityGenerator;

	UPROPERTY()
	TObjectPtr<ADayNightCycle> DayNight;

	bool bWorldBuilt = false;

	void SpawnStarterVehicle();
};
