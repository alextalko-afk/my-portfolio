#include "ArcadeVehicle.h"
#include "OpenWorldPlayerController.h"
#include "ProceduralTextureLibrary.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "Camera/CameraComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

AArcadeVehicle::AArcadeVehicle()
{
	PrimaryActorTick.bCanEverTick = true;

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(TEXT("/Engine/BasicShapes/Cube.Cube"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));

	CarBody = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CarBody"));
	RootComponent = CarBody;
	CarBody->SetRelativeScale3D(FVector(4.4f, 1.9f, 1.1f));
	CarBody->SetCollisionProfileName(TEXT("Pawn"));
	if (CubeMesh.Succeeded())
	{
		CarBody->SetStaticMesh(CubeMesh.Object);
	}

	const FVector WheelOffsets[4] = {
		FVector(140.f, 95.f, -55.f),
		FVector(140.f, -95.f, -55.f),
		FVector(-140.f, 95.f, -55.f),
		FVector(-140.f, -95.f, -55.f)
	};

	for (int32 i = 0; i < 4; ++i)
	{
		Wheels[i] = CreateDefaultSubobject<UStaticMeshComponent>(*FString::Printf(TEXT("Wheel%d"), i));
		Wheels[i]->SetupAttachment(RootComponent);
		Wheels[i]->SetRelativeLocation(WheelOffsets[i]);
		Wheels[i]->SetRelativeRotation(FRotator(0.f, 0.f, 90.f));
		Wheels[i]->SetRelativeScale3D(FVector(0.55f, 0.28f, 0.55f));
		Wheels[i]->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		if (CylinderMesh.Succeeded())
		{
			Wheels[i]->SetStaticMesh(CylinderMesh.Object);
		}
	}

	ChaseBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("ChaseBoom"));
	ChaseBoom->SetupAttachment(RootComponent);
	ChaseBoom->TargetArmLength = 650.f;
	ChaseBoom->SocketOffset = FVector(0.f, 0.f, 150.f);
	ChaseBoom->bUsePawnControlRotation = false;
	ChaseBoom->bInheritYaw = true;
	ChaseBoom->bInheritPitch = false;
	ChaseBoom->bInheritRoll = false;
	ChaseBoom->bEnableCameraLag = true;
	ChaseBoom->CameraLagSpeed = 3.f;

	ChaseCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("ChaseCamera"));
	ChaseCamera->SetupAttachment(ChaseBoom, USpringArmComponent::SocketName);
	ChaseCamera->bUsePawnControlRotation = false;
}

void AArcadeVehicle::BeginPlay()
{
	Super::BeginPlay();

	UMaterialInterface* BaseMaterial = LoadObject<UMaterialInterface>(nullptr, TEXT("/Game/Materials/M_Procedural.M_Procedural"));
	if (BaseMaterial)
	{
		UTexture2D* PaintTexture = ProceduralTextureLibrary::CreateSolidColorTexture(FColor(180, 30, 30, 255));
		if (UMaterialInstanceDynamic* BodyMID = UMaterialInstanceDynamic::Create(BaseMaterial, this))
		{
			BodyMID->SetTextureParameterValue(TEXT("BaseTexture"), PaintTexture);
			CarBody->SetMaterial(0, BodyMID);
		}

		UTexture2D* TireTexture = ProceduralTextureLibrary::CreateSolidColorTexture(FColor(20, 20, 20, 255));
		if (UMaterialInstanceDynamic* TireMID = UMaterialInstanceDynamic::Create(BaseMaterial, this))
		{
			TireMID->SetTextureParameterValue(TEXT("BaseTexture"), TireTexture);
			for (UStaticMeshComponent* Wheel : Wheels)
			{
				if (Wheel)
				{
					Wheel->SetMaterial(0, TireMID);
				}
			}
		}
	}
}

void AArcadeVehicle::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);

	PlayerInputComponent->BindAxis("Throttle", this, &AArcadeVehicle::Throttle);
	PlayerInputComponent->BindAxis("Steer", this, &AArcadeVehicle::Steer);
	PlayerInputComponent->BindAction("Interact", IE_Pressed, this, &AArcadeVehicle::RequestExit);
}

void AArcadeVehicle::Throttle(float Value)
{
	ThrottleInput = FMath::Clamp(Value, -1.f, 1.f);
}

void AArcadeVehicle::Steer(float Value)
{
	SteerInput = FMath::Clamp(Value, -1.f, 1.f);
}

void AArcadeVehicle::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (!bOccupied)
	{
		ThrottleInput = 0.f;
		SteerInput = 0.f;
	}

	const float TargetSpeed = ThrottleInput * MaxSpeed;
	const float Rate = (FMath::Abs(ThrottleInput) > KINDA_SMALL_NUMBER) ? Acceleration : BrakingDeceleration;
	CurrentSpeed = FMath::FInterpConstantTo(CurrentSpeed, TargetSpeed, DeltaSeconds, Rate);

	if (!FMath::IsNearlyZero(CurrentSpeed))
	{
		const float SpeedRatio = FMath::Clamp(FMath::Abs(CurrentSpeed) / MaxSpeed, 0.f, 1.f);
		const float TurnRate = FMath::Lerp(TurnRateAtStandstill, TurnRateAtMaxSpeed, SpeedRatio);
		const float Direction = CurrentSpeed >= 0.f ? 1.f : -1.f;

		FRotator NewRotation = GetActorRotation();
		NewRotation.Yaw += SteerInput * TurnRate * Direction * DeltaSeconds;
		SetActorRotation(NewRotation);
	}

	FHitResult Hit;
	AddActorWorldOffset(GetActorForwardVector() * CurrentSpeed * DeltaSeconds, true, &Hit);
	if (Hit.bBlockingHit)
	{
		CurrentSpeed *= 0.2f;
	}

	for (UStaticMeshComponent* Wheel : Wheels)
	{
		if (Wheel)
		{
			Wheel->AddLocalRotation(FRotator(0.f, 0.f, CurrentSpeed * DeltaSeconds * 0.35f));
		}
	}
}

void AArcadeVehicle::SetOccupied(bool bNewOccupied)
{
	bOccupied = bNewOccupied;
	if (!bOccupied)
	{
		ThrottleInput = 0.f;
		SteerInput = 0.f;
	}
}

FVector AArcadeVehicle::GetExitLocation() const
{
	return GetActorLocation() + GetActorRightVector() * 220.f + FVector(0.f, 0.f, 40.f);
}

void AArcadeVehicle::RequestExit()
{
	if (AOpenWorldPlayerController* PC = Cast<AOpenWorldPlayerController>(GetController()))
	{
		PC->ExitVehicle();
	}
}
