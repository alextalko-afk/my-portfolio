#include "OpenWorldPlayerController.h"
#include "OpenWorldCharacter.h"
#include "ArcadeVehicle.h"

void AOpenWorldPlayerController::OnPossess(APawn* InPawn)
{
	Super::OnPossess(InPawn);

	if (AOpenWorldCharacter* Character = Cast<AOpenWorldCharacter>(InPawn))
	{
		CachedCharacter = Character;
	}
}

void AOpenWorldPlayerController::EnterVehicle(AArcadeVehicle* Vehicle)
{
	if (!Vehicle || Vehicle->IsOccupied() || CurrentVehicle)
	{
		return;
	}

	if (AOpenWorldCharacter* Character = Cast<AOpenWorldCharacter>(GetPawn()))
	{
		CachedCharacter = Character;
		Character->SetActorHiddenInGame(true);
		Character->SetActorEnableCollision(false);
		Character->SetActorTickEnabled(false);
	}

	CurrentVehicle = Vehicle;
	Vehicle->SetOccupied(true);
	Possess(Vehicle);
}

void AOpenWorldPlayerController::ExitVehicle()
{
	if (!CurrentVehicle || !CachedCharacter)
	{
		return;
	}

	const FVector ExitLocation = CurrentVehicle->GetExitLocation();
	CurrentVehicle->SetOccupied(false);

	CachedCharacter->SetActorLocation(ExitLocation);
	CachedCharacter->SetActorHiddenInGame(false);
	CachedCharacter->SetActorEnableCollision(true);
	CachedCharacter->SetActorTickEnabled(true);

	Possess(CachedCharacter);
	CurrentVehicle = nullptr;
}
