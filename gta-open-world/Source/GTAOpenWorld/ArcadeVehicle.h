#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "ArcadeVehicle.generated.h"

class UStaticMeshComponent;
class USpringArmComponent;
class UCameraComponent;

// A drivable car using simple arcade-style movement math (accelerate/steer/brake
// applied directly to the actor transform) rather than Chaos Vehicles' wheel
// physics. That's a deliberate reliability tradeoff: this project can't be
// compiled or tested where it was written, and Chaos Vehicles' setup surface
// (wheel classes, physics asset config) is exactly the kind of thing that's easy
// to get subtly wrong blind. See README "Known limitations".
UCLASS()
class GTAOPENWORLD_API AArcadeVehicle : public APawn
{
	GENERATED_BODY()

public:
	AArcadeVehicle();

	bool IsOccupied() const { return bOccupied; }
	void SetOccupied(bool bNewOccupied);
	FVector GetExitLocation() const;

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

	void Throttle(float Value);
	void Steer(float Value);
	void RequestExit();

private:
	UPROPERTY(VisibleAnywhere)
	TObjectPtr<UStaticMeshComponent> CarBody;

	UPROPERTY(VisibleAnywhere)
	TObjectPtr<UStaticMeshComponent> Wheels[4];

	UPROPERTY(VisibleAnywhere)
	TObjectPtr<USpringArmComponent> ChaseBoom;

	UPROPERTY(VisibleAnywhere)
	TObjectPtr<UCameraComponent> ChaseCamera;

	UPROPERTY(EditDefaultsOnly, Category = "Driving")
	float MaxSpeed = 2200.f;

	UPROPERTY(EditDefaultsOnly, Category = "Driving")
	float Acceleration = 1600.f;

	UPROPERTY(EditDefaultsOnly, Category = "Driving")
	float BrakingDeceleration = 2600.f;

	UPROPERTY(EditDefaultsOnly, Category = "Driving")
	float TurnRateAtMaxSpeed = 20.f;

	UPROPERTY(EditDefaultsOnly, Category = "Driving")
	float TurnRateAtStandstill = 60.f;

	float CurrentSpeed = 0.f;
	float ThrottleInput = 0.f;
	float SteerInput = 0.f;
	bool bOccupied = false;
};
