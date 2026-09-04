#include "DayNightCycle.h"
#include "Engine/DirectionalLight.h"
#include "Engine/SkyLight.h"
#include "Components/LightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/SceneComponent.h"

ADayNightCycle::ADayNightCycle()
{
	PrimaryActorTick.bCanEverTick = true;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

void ADayNightCycle::BeginPlay()
{
	Super::BeginPlay();

	TimeOfDay = StartTimeOfDay;

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	Sun = GetWorld()->SpawnActor<ADirectionalLight>(ADirectionalLight::StaticClass(), FTransform::Identity, Params);
	if (Sun)
	{
		if (ULightComponent* LightComp = Sun->GetLightComponent())
		{
			LightComp->SetMobility(EComponentMobility::Movable);
			LightComp->Intensity = 8.f;
		}
	}

	Sky = GetWorld()->SpawnActor<ASkyLight>(ASkyLight::StaticClass(), FTransform::Identity, Params);
	if (Sky)
	{
		if (USkyLightComponent* SkyComp = Sky->GetLightComponent())
		{
			SkyComp->SetMobility(EComponentMobility::Movable);
			SkyComp->SourceType = ESkyLightSourceType::SLS_CapturedScene;
			SkyComp->RecaptureSky();
		}
	}
}

void ADayNightCycle::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	TimeOfDay = FMath::Fmod(TimeOfDay + DeltaSeconds / FMath::Max(DaySeconds, 1.f), 1.f);

	if (Sun)
	{
		const float SunPitch = (TimeOfDay * 360.f) - 90.f;
		Sun->SetActorRotation(FRotator(SunPitch, -30.f, 0.f));

		const float HeightFactor = FMath::Sin(TimeOfDay * 2.f * PI);
		const float DayAmount = FMath::Clamp(HeightFactor + 0.15f, 0.f, 1.f);
		const float Warmth = 1.f - FMath::Clamp(HeightFactor * 2.f, 0.f, 1.f);

		if (ULightComponent* LightComp = Sun->GetLightComponent())
		{
			LightComp->Intensity = FMath::Lerp(0.15f, 9.f, DayAmount);
			LightComp->LightColor = FLinearColor::LerpUsingHSV(
				FLinearColor(1.f, 0.97f, 0.92f), FLinearColor(1.f, 0.55f, 0.32f), Warmth).ToFColor(false);
		}
	}

	TimeSinceSkyRecapture += DeltaSeconds;
	if (Sky && TimeSinceSkyRecapture > 2.f)
	{
		TimeSinceSkyRecapture = 0.f;
		if (USkyLightComponent* SkyComp = Sky->GetLightComponent())
		{
			SkyComp->RecaptureSky();
		}
	}
}
