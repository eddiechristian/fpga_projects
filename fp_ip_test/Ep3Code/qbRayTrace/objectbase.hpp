/* ***********************************************************
	objectbase.hpp
	
	The objectbase class definition - A base class from which
	all other object classes will inherit.
	
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

// objectbase.hpp

#ifndef OBJECTBASE_H
#define OBJECTBASE_H

#include "./qbLinAlg/qbVector.h"
#include "ray.hpp"

namespace qbRT
{
	class ObjectBase
	{
		public:
			// Constructor and destructor.
			ObjectBase();
			virtual ~ObjectBase();
			
			// Function to test for intersections.
			virtual bool TestIntersection(const Ray &castRay, qbVector<float> &intPoint, qbVector<float> &localNormal, qbVector<float> &localColor);
			
			// Function to test whether two floating-point numbers are close to being equal.
			bool CloseEnough(const float f1, const float f2);
			
		// Public member variables.
		public:
			// The base colour of the object.
			qbVector<float> m_baseColor {3};
	};
}

#endif
