#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "OpenWorldPlayerController.generated.h"

class AOpenWorldCharacter;
class AArcadeVehicle;

// Owns the enter/exit handshake between the on-foot character and a vehicle. This
// lives on the controller (not the pawns) because a pawn loses its Controller
// pointer the moment it's un-possessed, so the character can't reliably hold onto
// "its own" controller across a Possess(Vehicle) call - the controller, by contrast,
// persists across both pawns for the whole session.
UCLASS()
class GTAOPENWORLD_API AOpenWorldPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	void EnterVehicle(AArcadeVehicle* Vehicle);
	void ExitVehicle();

protected:
	virtual void OnPossess(APawn* InPawn) override;

private:
	UPROPERTY()
	TObjectPtr<AOpenWorldCharacter> CachedCharacter;

	UPROPERTY()
	TObjectPtr<AArcadeVehicle> CurrentVehicle;
};
