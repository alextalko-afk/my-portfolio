#include "ProceduralTextureLibrary.h"
#include "Engine/Texture2D.h"
#include "Math/RandomStream.h"

namespace
{
	UTexture2D* CreateTextureFromPixels(const TArray<FColor>& Pixels, int32 Width, int32 Height)
	{
		UTexture2D* Texture = UTexture2D::CreateTransient(Width, Height, PF_B8G8R8A8);
		if (!Texture)
		{
			return nullptr;
		}

#if WITH_EDITORONLY_DATA
		Texture->MipGenSettings = TMGS_NoMipmaps;
#endif
		Texture->NeverStream = true;
		Texture->SRGB = true;

		FTexture2DMipMap& Mip = Texture->GetPlatformData()->Mips[0];
		void* Data = Mip.BulkData.Lock(LOCK_READ_WRITE);
		FMemory::Memcpy(Data, Pixels.GetData(), Pixels.Num() * sizeof(FColor));
		Mip.BulkData.Unlock();

		Texture->UpdateResource();
		return Texture;
	}

	uint8 ClampByte(float Value)
	{
		return static_cast<uint8>(FMath::Clamp(Value, 0.f, 255.f));
	}
}

UTexture2D* ProceduralTextureLibrary::CreateSolidColorTexture(const FColor& Color, int32 Size)
{
	TArray<FColor> Pixels;
	Pixels.Init(Color, Size * Size);
	return CreateTextureFromPixels(Pixels, Size, Size);
}

UTexture2D* ProceduralTextureLibrary::CreateNoiseTexture(const FColor& BaseColor, float Variation, int32 Size, int32 Seed)
{
	FRandomStream Stream(Seed);
	TArray<FColor> Pixels;
	Pixels.Reserve(Size * Size);

	for (int32 i = 0; i < Size * Size; ++i)
	{
		const float Noise = Stream.FRandRange(-Variation, Variation) * 255.f;
		Pixels.Add(FColor(
			ClampByte(BaseColor.R + Noise),
			ClampByte(BaseColor.G + Noise),
			ClampByte(BaseColor.B + Noise),
			255));
	}

	return CreateTextureFromPixels(Pixels, Size, Size);
}

UTexture2D* ProceduralTextureLibrary::CreateAsphaltTexture(int32 Size, int32 Seed)
{
	FRandomStream Stream(Seed);
	TArray<FColor> Pixels;
	Pixels.Reserve(Size * Size);

	for (int32 y = 0; y < Size; ++y)
	{
		for (int32 x = 0; x < Size; ++x)
		{
			const float Noise = Stream.FRandRange(-15.f, 15.f);
			const uint8 Shade = ClampByte(45.f + Noise);
			FColor Pixel(Shade, Shade, ClampByte(Shade + 3.f), 255);

			const bool bCenterBand = FMath::Abs(x - Size / 2) < FMath::Max(Size / 64, 1);
			const bool bDash = ((y / FMath::Max(Size / 8, 1)) % 2) == 0;
			if (bCenterBand && bDash)
			{
				Pixel = FColor(230, 205, 90, 255);
			}

			Pixels.Add(Pixel);
		}
	}

	return CreateTextureFromPixels(Pixels, Size, Size);
}

UTexture2D* ProceduralTextureLibrary::CreateFacadeTexture(int32 Floors, int32 WindowsPerFloor, const FColor& WallColor, int32 Seed, int32 Size)
{
	FRandomStream Stream(Seed);
	TArray<FColor> Pixels;
	Pixels.Init(WallColor, Size * Size);

	Floors = FMath::Max(Floors, 1);
	WindowsPerFloor = FMath::Max(WindowsPerFloor, 1);

	const float FloorHeightPx = static_cast<float>(Size) / Floors;
	const float WindowWidthPx = static_cast<float>(Size) / WindowsPerFloor;
	const float MarginX = WindowWidthPx * 0.2f;
	const float MarginY = FloorHeightPx * 0.25f;

	const FColor LitColor(255, 214, 140, 255);
	const FColor DarkColor(40, 52, 60, 255);

	for (int32 Floor = 0; Floor < Floors; ++Floor)
	{
		for (int32 Col = 0; Col < WindowsPerFloor; ++Col)
		{
			const bool bLit = Stream.FRand() > 0.55f;
			const FColor WindowColor = bLit ? LitColor : DarkColor;

			const int32 X0 = FMath::Clamp(FMath::FloorToInt(Col * WindowWidthPx + MarginX), 0, Size - 1);
			const int32 X1 = FMath::Clamp(FMath::FloorToInt((Col + 1) * WindowWidthPx - MarginX), 0, Size);
			const int32 Y0 = FMath::Clamp(FMath::FloorToInt(Floor * FloorHeightPx + MarginY), 0, Size - 1);
			const int32 Y1 = FMath::Clamp(FMath::FloorToInt((Floor + 1) * FloorHeightPx - MarginY), 0, Size);

			for (int32 y = Y0; y < Y1; ++y)
			{
				for (int32 x = X0; x < X1; ++x)
				{
					Pixels[y * Size + x] = WindowColor;
				}
			}
		}
	}

	for (FColor& Pixel : Pixels)
	{
		if (Pixel != LitColor && Pixel != DarkColor)
		{
			const float Noise = Stream.FRandRange(-10.f, 10.f);
			Pixel.R = ClampByte(Pixel.R + Noise);
			Pixel.G = ClampByte(Pixel.G + Noise);
			Pixel.B = ClampByte(Pixel.B + Noise);
		}
	}

	return CreateTextureFromPixels(Pixels, Size, Size);
}

UTexture2D* ProceduralTextureLibrary::CreateGroundTexture(int32 Size, int32 Seed)
{
	return CreateNoiseTexture(FColor(58, 92, 48, 255), 0.12f, Size, Seed);
}
