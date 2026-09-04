#include "OpenWorldCharacter.h"
#include "OpenWorldPlayerController.h"
#include "ArcadeVehicle.h"
#include "ProceduralTextureLibrary.h"
#include "GameFramework/SpringArmComponent.h"
#include "Camera/CameraComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Kismet/GameplayStatics.h"
#include "UObject/ConstructorHelpers.h"

AOpenWorldCharacter::AOpenWorldCharacter()
{
	PrimaryActorTick.bCanEverTick = false;

	GetCapsuleComponent()->InitCapsuleSize(42.f, 96.f);

	bUseControllerRotationYaw = false;

	GetCharacterMovement()->bOrientRotationToMovement = true;
	GetCharacterMovement()->RotationRate = FRotator(0.f, 540.f, 0.f);
	GetCharacterMovement()->JumpZVelocity = 500.f;
	GetCharacterMovement()->AirControl = 0.2f;
	GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(RootComponent);
	CameraBoom->TargetArmLength = 450.f;
	CameraBoom->SocketOffset = FVector(0.f, 60.f, 80.f);
	CameraBoom->bUsePawnControlRotation = true;

	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	FollowCamera->bUsePawnControlRotation = false;

	// Block-out body from engine-default primitives - no skeletal mesh/animation
	// blueprint, since those are authored visually in-editor and can't be produced
	// blind (see README "Known limitations").
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(TEXT("/Engine/BasicShapes/Sphere.Sphere"));

	TorsoMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("TorsoMesh"));
	TorsoMesh->SetupAttachment(RootComponent);
	TorsoMesh->SetRelativeLocation(FVector(0.f, 0.f, -20.f));
	TorsoMesh->SetRelativeScale3D(FVector(0.6f, 0.6f, 1.1f));
	TorsoMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	if (CylinderMesh.Succeeded())
	{
		TorsoMesh->SetStaticMesh(CylinderMesh.Object);
	}

	HeadMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("HeadMesh"));
	HeadMesh->SetupAttachment(TorsoMesh);
	HeadMesh->SetRelativeLocation(FVector(0.f, 0.f, 65.f));
	HeadMesh->SetRelativeScale3D(FVector(0.45f, 0.45f, 0.45f));
	HeadMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	if (SphereMesh.Succeeded())
	{
		HeadMesh->SetStaticMesh(SphereMesh.Object);
	}
}

void AOpenWorldCharacter::BeginPlay()
{
	Super::BeginPlay();

	UMaterialInterface* BaseMaterial = LoadObject<UMaterialInterface>(nullptr, TEXT("/Game/Materials/M_Procedural.M_Procedural"));
	if (BaseMaterial)
	{
		UTexture2D* SkinTexture = ProceduralTextureLibrary::CreateSolidColorTexture(FColor(70, 90, 130, 255));
		if (UMaterialInstanceDynamic* MID = UMaterialInstanceDynamic::Create(BaseMaterial, this))
		{
			MID->SetTextureParameterValue(TEXT("BaseTexture"), SkinTexture);
			TorsoMesh->SetMaterial(0, MID);
			HeadMesh->SetMaterial(0, MID);
		}
	}
}

void AOpenWorldCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);

	PlayerInputComponent->BindAxis("MoveForward", this, &AOpenWorldCharacter::MoveForward);
	PlayerInputComponent->BindAxis("MoveRight", this, &AOpenWorldCharacter::MoveRight);
	PlayerInputComponent->BindAxis("Turn", this, &APawn::AddControllerYawInput);
	PlayerInputComponent->BindAxis("LookUp", this, &APawn::AddControllerPitchInput);

	PlayerInputComponent->BindAction("Jump", IE_Pressed, this, &ACharacter::Jump);
	PlayerInputComponent->BindAction("Jump", IE_Released, this, &ACharacter::StopJumping);
	PlayerInputComponent->BindAction("Sprint", IE_Pressed, this, &AOpenWorldCharacter::StartSprint);
	PlayerInputComponent->BindAction("Sprint", IE_Released, this, &AOpenWorldCharacter::StopSprint);
	PlayerInputComponent->BindAction("Interact", IE_Pressed, this, &AOpenWorldCharacter::TryInteract);
}

void AOpenWorldCharacter::MoveForward(float Value)
{
	if (Controller && Value != 0.f)
	{
		const FRotator YawRotation(0.f, Controller->GetControlRotation().Yaw, 0.f);
		AddMovementInput(FRotationMatrix(YawRotation).GetUnitAxis(EAxis::X), Value);
	}
}

void AOpenWorldCharacter::MoveRight(float Value)
{
	if (Controller && Value != 0.f)
	{
		const FRotator YawRotation(0.f, Controller->GetControlRotation().Yaw, 0.f);
		AddMovementInput(FRotationMatrix(YawRotation).GetUnitAxis(EAxis::Y), Value);
	}
}

void AOpenWorldCharacter::StartSprint()
{
	GetCharacterMovement()->MaxWalkSpeed = SprintSpeed;
}

void AOpenWorldCharacter::StopSprint()
{
	GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
}

void AOpenWorldCharacter::TryInteract()
{
	// Polling-based proximity check rather than overlap events/collision channels -
	// fewer moving parts to get wrong blind, at a trivial cost given how few vehicles
	// exist in this mini-slice.
	TArray<AActor*> Vehicles;
	UGameplayStatics::GetAllActorsOfClass(GetWorld(), AArcadeVehicle::StaticClass(), Vehicles);

	AArcadeVehicle* Nearest = nullptr;
	float NearestDistSq = FMath::Square(InteractRange);

	for (AActor* Actor : Vehicles)
	{
		AArcadeVehicle* Vehicle = Cast<AArcadeVehicle>(Actor);
		if (!Vehicle || Vehicle->IsOccupied())
		{
			continue;
		}

		const float DistSq = FVector::DistSquared(GetActorLocation(), Vehicle->GetActorLocation());
		if (DistSq <= NearestDistSq)
		{
			NearestDistSq = DistSq;
			Nearest = Vehicle;
		}
	}

	if (Nearest)
	{
		if (AOpenWorldPlayerController* PC = Cast<AOpenWorldPlayerController>(GetController()))
		{
			PC->EnterVehicle(Nearest);
		}
	}
}
