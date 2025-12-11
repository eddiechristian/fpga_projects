/* ***********************************************************
	camera.hpp
	
	The camera class definition - A class to handle the camera
	and compute camera geometry.
	
	This file forms part of the qbRayTrace project as described
	in the series of videos on the QuantitativeBytes YouTube
	channel.
	
	This code corresponds specifically to Episode 2 of the series,
	which may be found here:
	https://youtu.be/KBK6g6RFgdA
	
	The whole series may be found on the QuantitativeBytes 
	YouTube channel at:
	www.youtube.com/c/QuantitativeBytes
	
	GPLv3 LICENSE
	Copyright (c) 2021 Michael Bennett
	
***********************************************************/

// camera.hpp

#ifndef CAMERA_H
#define CAMERA_H

#include "./qbLinAlg/qbVector.h"
#include "ray.hpp"

namespace qbRT
{
	class Camera
	{
		public:
			// The default constructor.
			Camera();
			
			// Functions to set camera parameters.
			void SetPosition	(const qbVector<float> &newPosition);
			void SetLookAt		(const qbVector<float> &newLookAt);
			void SetUp				(const qbVector<float> &upVector);
			void SetLength		(float newLength);
			void SetHorzSize	(float newSize);
			void SetAspect		(float newAspect);
			
			// Functions to return camera parameters.
			qbVector<float>	GetPosition();
			qbVector<float>	GetLookAt();
			qbVector<float>	GetUp();
			qbVector<float>	GetU();
			qbVector<float>	GetV();
			qbVector<float>	GetScreenCentre();
			float						GetLength();
			float						GetHorzSize();
			float						GetAspect();
			
			// Function to generate a ray.
			bool GenerateRay(float proScreenX, float proScreenY, qbRT::Ray &cameraRay);
			
			// Function to update the camera geometry.
			void UpdateCameraGeometry();
			
		private:
			qbVector<float> m_cameraPosition	{3};
			qbVector<float> m_cameraLookAt		{3};
			qbVector<float> m_cameraUp				{3};
			float m_cameraLength;
			float m_cameraHorzSize;
			float m_cameraAspectRatio;
			
			qbVector<float> m_alignmentVector				{3};
			qbVector<float> m_projectionScreenU			{3};
			qbVector<float> m_projectionScreenV			{3};
			qbVector<float> m_projectionScreenCentre	{3};
			
	};
}

#endif
