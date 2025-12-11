/* ***********************************************************
	objectsphere.cpp

	The objectsphere class implementation - A class to implement
	spheres. Inherits from objectbase.hpp

	This file forms part of the qbRayTrace project as described
	in the series of videos on the QuantitativeBytes YouTube
	channel.

	This code corresponds specifically to Episode 3 of the series,
	which may be found here:
	https://youtu.be/8fWZM8hCX5E

	The whole series may be found on the QuantitativeBytes
	YouTube channel at:
	www.youtube.com/c/QuantitativeBytes

	GPLv3 LICENSE
	Copyright (c) 2021 Michael Bennett

***********************************************************/

// objsphere.cpp

#include "objsphere.hpp"
#include <cmath>

// The default constructor.
qbRT::ObjSphere::ObjSphere()
{
}

// The destructor.
qbRT::ObjSphere::~ObjSphere()
{
}

// Function to test for intersections.
bool qbRT::ObjSphere::TestIntersection(const qbRT::Ray &castRay, qbVector<float> &intPoint, qbVector<float> &localNormal, qbVector<float> &localColor)
{
	// Compute the values of a, b and c.
	static int cnt = 0;
	qbVector<float> vhat = castRay.m_lab;
	vhat.Normalize();

	/* Note that a is equal to the squared magnitude of the
		direction of the cast ray. As this will be a unit vector,
		we can conclude that the value of 'a' will always be 1. */
	// a = 1.0;

	// Calculate b.
	float b = 2.0 * qbVector<float>::dot(castRay.m_point1, vhat);

	// Calculate c.
	float c = qbVector<float>::dot(castRay.m_point1, castRay.m_point1) - 1.0;

	// Test whether we actually have an intersection.
	float intTest = (b * b) - 4.0 * c;

	if (intTest > 0.0)
	{
		float numSQRT = sqrtf(intTest);
		float t1 = (-b + numSQRT) / 2.0;
		float t2 = (-b - numSQRT) / 2.0;
		if (cnt < 3)
		{
			printf("castRay.m_lab.x=%.6f castRay.m_lab.y=%.6f castRay.m_lab.z=%.6f\n", castRay.m_lab.GetElement(0), castRay.m_lab.GetElement(1), castRay.m_lab.GetElement(2));
			printf("vhat.x=%.6f vhat.y=%.6f vhat.z=%.6f\n", vhat.GetElement(0), vhat.GetElement(1), vhat.GetElement(2));
			printf("castRay.m_point1.x=%.6f castRay.m_point1.y=%.6f castRay.m_point1.z=%.6f\n", castRay.m_point1.GetElement(0), castRay.m_point1.GetElement(1), castRay.m_point1.GetElement(2));
			printf("castRay.m_point2.x=%.6f castRay.m_point2.y=%.6f castRay.m_point2.z=%.6f\n", castRay.m_point2.GetElement(0), castRay.m_point2.GetElement(1), castRay.m_point2.GetElement(2));
			printf("b=%.6f c=%.6f b*b=%.8f 4*c=%.8f\n", b, c, b * b, 4 * c);
			printf("inttest=%.6f\n", intTest);
		}

		/* If either t1 or t2 are negative, then at least part of the object is
			behind the camera and so we will ignore it. */
		if ((t1 < 0.0) || (t2 < 0.0))
		{
			return false;
		}
		else
		{
			// Determine which point of intersection was closest to the camera.
			if (t1 < t2)
			{
				intPoint = castRay.m_point1 + (vhat * t1);
			}
			else
			{
				intPoint = castRay.m_point1 + (vhat * t2);
			}
			if (cnt < 3)
			{
				printf("intPoint.x=%.6f intPoint.y=%.6f intPoint.z=%.6f\n", intPoint.GetElement(0), intPoint.GetElement(1), intPoint.GetElement(2));
				printf("\n");
			}
		}
		cnt++;
		return true;
	}
	else
	{
		return false;
	}
}
