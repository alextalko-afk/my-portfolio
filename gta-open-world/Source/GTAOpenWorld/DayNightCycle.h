#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "DayNightCycle.generated.h"

class ADirectionalLight;
class ASkyLight;

// Spawns and animates a sun + sky light with no level-placed lighting actors
// required. One full day/night cycle takes DaySeconds real-world seconds.
UCLASS()
class GTAOPENWORLD_API ADayNightCycle : public AActor
{
	GENERATED_BODY()

public:
	ADayNightCycle();

	UPROPERTY(EditAnywhere, Category = "DayNight")
	float DaySeconds = 300.f;

	UPROPERTY(EditAnywhere, Category = "DayNight")
	float StartTimeOfDay = 0.35f;

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;

private:
	UPROPERTY()
	TObjectPtr<ADirectionalLight> Sun;

	UPROPERTY()
	TObjectPtr<ASkyLight> Sky;

	float TimeOfDay = 0.f;
	float TimeSinceSkyRecapture = 0.f;
};
