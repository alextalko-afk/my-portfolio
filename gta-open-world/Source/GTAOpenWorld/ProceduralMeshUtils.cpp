#include "ProceduralMeshUtils.h"

namespace
{
	// Shared quad appender: A-B-C-D must be wound counter-clockwise as seen from the
	// direction Normal points (matches Epic's own ProceduralMeshComponent examples).
	// If a face renders back-face-culled/invisible from the expected side once this
	// is opened in-editor, swap the (0,1,2)/(0,2,3) triangle winding below - see the
	// "Known limitations" note in README.md, this couldn't be verified without a
	// running renderer in the environment this was authored in.
	void AppendQuad(FProcMeshData& MeshData, const FVector& A, const FVector& B, const FVector& C, const FVector& D, const FVector& Normal, float UMax, float VMax)
	{
		const int32 Base = MeshData.Vertices.Num();
		MeshData.Vertices.Add(A);
		MeshData.Vertices.Add(B);
		MeshData.Vertices.Add(C);
		MeshData.Vertices.Add(D);

		for (int32 i = 0; i < 4; ++i)
		{
			MeshData.Normals.Add(Normal);
		}

		MeshData.UVs.Add(FVector2D(0.f, VMax));
		MeshData.UVs.Add(FVector2D(UMax, VMax));
		MeshData.UVs.Add(FVector2D(UMax, 0.f));
		MeshData.UVs.Add(FVector2D(0.f, 0.f));

		const FVector Tangent = (B - A).GetSafeNormal();
		for (int32 i = 0; i < 4; ++i)
		{
			MeshData.Tangents.Add(FProcMeshTangent(Tangent, false));
		}

		MeshData.Triangles.Add(Base + 0);
		MeshData.Triangles.Add(Base + 1);
		MeshData.Triangles.Add(Base + 2);
		MeshData.Triangles.Add(Base + 0);
		MeshData.Triangles.Add(Base + 2);
		MeshData.Triangles.Add(Base + 3);
	}

	float TileCount(float WorldSize, float UVTiling)
	{
		return FMath::Max(WorldSize / 100.f, 0.25f) * UVTiling;
	}
}

void ProceduralMeshUtils::AddBox(FProcMeshData& MeshData, const FVector& BottomCenter, const FVector& Size, float UVTiling)
{
	const float HX = Size.X * 0.5f;
	const float HY = Size.Y * 0.5f;
	const float Z0 = BottomCenter.Z;
	const float Z1 = BottomCenter.Z + Size.Z;
	const float CX = BottomCenter.X;
	const float CY = BottomCenter.Y;

	const FVector V000(CX - HX, CY - HY, Z0);
	const FVector V100(CX + HX, CY - HY, Z0);
	const FVector V110(CX + HX, CY + HY, Z0);
	const FVector V010(CX - HX, CY + HY, Z0);
	const FVector V001(CX - HX, CY - HY, Z1);
	const FVector V101(CX + HX, CY - HY, Z1);
	const FVector V111(CX + HX, CY + HY, Z1);
	const FVector V011(CX - HX, CY + HY, Z1);

	const float UWidth = TileCount(Size.X, UVTiling);
	const float UDepth = TileCount(Size.Y, UVTiling);
	const float VHeight = TileCount(Size.Z, UVTiling);

	AppendQuad(MeshData, V000, V100, V101, V001, FVector(0, -1, 0), UWidth, VHeight); // front (-Y)
	AppendQuad(MeshData, V110, V010, V011, V111, FVector(0, 1, 0), UWidth, VHeight);  // back (+Y)
	AppendQuad(MeshData, V010, V000, V001, V011, FVector(-1, 0, 0), UDepth, VHeight); // left (-X)
	AppendQuad(MeshData, V100, V110, V111, V101, FVector(1, 0, 0), UDepth, VHeight);  // right (+X)
	AppendQuad(MeshData, V001, V101, V111, V011, FVector(0, 0, 1), UWidth, UDepth);   // top (+Z)
	AppendQuad(MeshData, V010, V110, V100, V000, FVector(0, 0, -1), UWidth, UDepth);  // bottom (-Z)
}

void ProceduralMeshUtils::AddGroundQuad(FProcMeshData& MeshData, const FVector& Origin, const FVector2D& HalfSize, float UVTiling)
{
	const FVector A(Origin.X - HalfSize.X, Origin.Y - HalfSize.Y, Origin.Z);
	const FVector B(Origin.X + HalfSize.X, Origin.Y - HalfSize.Y, Origin.Z);
	const FVector C(Origin.X + HalfSize.X, Origin.Y + HalfSize.Y, Origin.Z);
	const FVector D(Origin.X - HalfSize.X, Origin.Y + HalfSize.Y, Origin.Z);

	AppendQuad(MeshData, A, B, C, D, FVector(0, 0, 1), TileCount(HalfSize.X * 2.f, UVTiling), TileCount(HalfSize.Y * 2.f, UVTiling));
}

void ProceduralMeshUtils::AddVerticalQuad(FProcMeshData& MeshData, const FVector& BottomCenter, float Width, float Height, const FVector& FacingNormal, float UVTiling)
{
	const FVector Right = FVector::CrossProduct(FVector::UpVector, FacingNormal).GetSafeNormal() * (Width * 0.5f);
	const FVector A = BottomCenter - Right;
	const FVector B = BottomCenter + Right;
	const FVector C = B + FVector(0, 0, Height);
	const FVector D = A + FVector(0, 0, Height);

	AppendQuad(MeshData, A, B, C, D, FacingNormal, TileCount(Width, UVTiling), TileCount(Height, UVTiling));
}
