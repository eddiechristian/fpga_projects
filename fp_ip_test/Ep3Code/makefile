# Define the link target.
linkTarget = qbRay

# SDL2 paths from raytracing project
SDL2_DIR = /home/eddie/raytracing/qbRayTrace/Ep1Code/third_party/sdl2-install
SDL2_INCLUDE = $(SDL2_DIR)/include
SDL2_LIB = $(SDL2_DIR)/lib

# Define the libraries that we need.
LIBS = -L$(SDL2_LIB) -lSDL2 -Wl,-rpath,$(SDL2_LIB)

# Define any flags.
CFLAGS = -std=c++17 -Ofast -I$(SDL2_INCLUDE)

# Define the object files that we need to use.
objects =	main.o \
					CApp.o \
					$(patsubst %.cpp,%.o,$(wildcard ./qbRayTrace/*.cpp))
					
# Define the rebuildables.
rebuildables = $(objects) $(linkTarget)

# Rule to actually perform the build.
$(linkTarget): $(objects)
	g++ -g -o $(linkTarget) $(objects) $(LIBS) $(CFLAGS)
	
# Rule to create the .o (object) files.
%.o: %.cpp
	g++ -o $@ -c $< $(CFLAGS)
	
.PHONEY:
clean:
	rm $(rebuildables)
