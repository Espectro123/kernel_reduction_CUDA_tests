#include <iostream>
#include <fstream>
#include <string.h>
#include <sys/time.h>
#include <stdlib.h>     /* srand, rand */
#include <time.h>       /* time */

using namespace std;

//Poner esto a 1 para imprimir los resultados


double cpuSecond(){

	struct timeval tp;
	gettimeofday(&tp, NULL);
	return((double)tp.tv_sec + (double)tp.tv_usec*1e-6);
}
int maximo_local(int* vector,int N){

    int maximo = 0;

    for(int i = 0; i < N; i++){

        if(vector[i] > maximo)
            maximo = vector[i];

    }

    return maximo;
}


__global__ void kernel_reduccion_intervalos(int* device_vector,int* device_salida){

  extern __shared__ int datos[];

  int tid = threadIdx.x; //numero de hebra

  int posicion = blockIdx.x * blockDim.x + threadIdx.x;
  int index = 0;

  datos[tid] = device_vector[posicion];

  for(int i = 1; i > blockDim.x; i *= 2){
    index = 2 * i * tid;

    if(index < blockDim.x){

      if(datos[tid] < datos[tid+i]){

        datos[tid] = datos[tid+i];

      }

    }
      __syncthreads();
  }


  //Guardo los resultados en el vector D
    if(device_salida[blockIdx.x] == 0){

      device_salida[blockIdx.x] = datos[0];
    }

}

__global__ void kernel_reduccion_secuencial(int* device_vector,int* device_salida){

    extern __shared__ int datos[];

    int tid = threadIdx.x; //numero de hebra

    int posicion = blockIdx.x * blockDim.x + threadIdx.x;

    datos[tid] = device_vector[posicion];


    __syncthreads();

    for(int i = blockDim.x/2; i > 0; i >>= 1){

      if(tid < i){

        if(datos[tid] < datos[tid+1]){

          datos[tid] = datos[tid+1];

        }

      }
        __syncthreads();
    }


    //Guardo los resultados en el vector D
      if(device_salida[blockIdx.x] == 0){

        device_salida[blockIdx.x] = datos[0];
      }
}

__device__ void desenrrollado_reduce_32(volatile int* datos, int tid){

    if(datos[tid] < datos[tid+32]) datos[tid] = datos[tid+32];
    if(datos[tid] < datos[tid+16]) datos[tid] = datos[tid+16];
    if(datos[tid] < datos[tid+8]) datos[tid] = datos[tid+8];
    if(datos[tid] < datos[tid+4]) datos[tid] = datos[tid+4];
    if(datos[tid] < datos[tid+2]) datos[tid] = datos[tid+2];
    if(datos[tid] < datos[tid+1]) datos[tid] = datos[tid+1];


}

__global__ void kernel_reduccion_desenrrollado_parcial(int* device_vector,int* device_salida){

    extern __shared__ int datos[];

    int tid = threadIdx.x; //numero de hebra

    int posicion = blockIdx.x * blockDim.x + threadIdx.x;

    datos[tid] = device_vector[posicion];


    for(int i = blockDim.x/2; i > 32; i >>= 1){

      if(tid < i){

        if(datos[tid] < datos[tid+1]){

          datos[tid] = datos[tid+1];

        }

      }
        __syncthreads();
    }

    if(tid < 32) desenrrollado_reduce_32(datos,tid);

    //Guardo los resultados en el vector D
      if(device_salida[blockIdx.x] == 0){

        device_salida[blockIdx.x] = datos[0];
      }

}

//para bloques de 2048
__global__ void kernel_reduccion_desenrrollado_total(int* device_vector,int* device_salida){

    extern __shared__ int datos[];

    int tid = threadIdx.x; //numero de hebra

    int posicion = blockIdx.x * blockDim.x + threadIdx.x;

    datos[tid] = device_vector[posicion];

    if(blockDim.x >= 2048){
        if(tid < 1024){
            if(datos[tid] < datos[tid + 1024]){
                datos[tid] = datos[tid + 1024];
            }
        }
    }

    if(blockDim.x >= 1024){
        if(tid < 512){
            if(datos[tid] < datos[tid + 512]){
                datos[tid] = datos[tid + 512];
            }
        }
        __syncthreads();
    }

    if(blockDim.x >= 512){
        if(tid < 256){
            if(datos[tid] < datos[tid + 256]){
                datos[tid] = datos[tid + 256];
            }
        }
        __syncthreads();
    }

    if(blockDim.x >= 256){
        if(tid < 128){
            if(datos[tid] < datos[tid + 128]){
                datos[tid] = datos[tid + 128];
            }
        }
        __syncthreads();
    }
    if(blockDim.x >= 128){
        if(tid < 64){
            if(datos[tid] < datos[tid + 64]){
                datos[tid] = datos[tid + 64];
            }
        }
        __syncthreads();
    }

    if(tid < 32) desenrrollado_reduce_32(datos,tid);

    __syncthreads();
    //Guardo los resultados en el vector D
      if(device_salida[blockIdx.x] == 0){

        device_salida[blockIdx.x] = datos[0];
      }
}



int main(int argc, char* argv[]){

    bool imprimir = false;


    if(argc < 4){
        cout << "Sintaxis: ./program <Numero de kernel a ejecutar> <Tamaño del problema> <Numero de bloques> "  << endl;
        exit(-1);
    }

    //Depuracion de errores CUDA
    int devID;
    cudaError_t error_cuda;

    error_cuda = cudaGetDevice(&devID);
    if(error_cuda != cudaSuccess){

      cout << "Error. No hay tarjeta grafica nvdia o no esta instalado el driver" << endl;
      exit(-1);

    }

    cudaDeviceProp propiedades;
    cudaGetDeviceProperties(&propiedades, devID);

    if(imprimir)
        cout << "Device " << devID << " " << propiedades.name << " con capacidad computacional: " << propiedades.major << "." << propiedades.minor << endl;

    //Kernel a ejecutar
    int kernel = atoi(argv[1]);

    //Tamaño del problema
    int N      = atoi(argv[2]);

    int bloques_por_grid  = atoi(argv[3]);

    //Memoria que es necesaria reservar para el vector device
    int device_memory = N*sizeof(int);

    int* vector = new int[N];
    int* resultado = new int[N];

    int* device_vector;
    int* device_salida;

    //Reservor la memoria para el vector device
    error_cuda = cudaMalloc( (void**) &device_vector, device_memory);

    if(error_cuda != cudaSuccess){

        cout << "No se ha podido reservar memoria para el vector <device_vector>" << endl;
        exit(-1);

    }

    error_cuda = cudaMalloc( (void**) &device_salida, bloques_por_grid*sizeof(int));
    if(error_cuda != cudaSuccess){

        cout << "No se ha podido reservar memoria para el vector <device_salida>" << endl;
        exit(-1);

    }

    //rellena el vecto con numero de 1 a N aleatorios
    int numero_random = 0;
    int maximo = -1;
    srand(time(NULL));
    for(int i = 0; i < N; i++){

        numero_random = rand() % N + 1;
        if(numero_random > maximo)
            maximo = numero_random;

        vector[i] = numero_random;

        resultado[i] = 0;
    }

    //Copio el contenido del vector a el vector device
    error_cuda = cudaMemcpy(device_vector,vector,device_memory, cudaMemcpyHostToDevice);
    if(error_cuda != cudaSuccess){

        cout << "No se pudo copair el contenido de <vector> a el vector device <device_vector>" << endl;
        exit(-1);

    }

    //Pongo a 0 todas las casillas del vector <<vector_salida>>
    error_cuda = cudaMemcpy(device_salida,resultado, bloques_por_grid*sizeof(int), cudaMemcpyHostToDevice);
    if(error_cuda != cudaSuccess){

        cout << "No se pudo copair el contenido de <resultado> a el vector device <device_salida>" << endl;
        exit(-1);

    }

    int hebras = ceil(N/bloques_por_grid);




    double tiempo = cpuSecond();

    switch(kernel){

        case 0:
            kernel_reduccion_intervalos<<<bloques_por_grid,hebras,sizeof(int)*bloques_por_grid>>>(device_vector, device_salida);
        break;

        case 1:
            kernel_reduccion_secuencial<<<bloques_por_grid,hebras,sizeof(int)*bloques_por_grid>>>(device_vector, device_salida);
        break;

        case 2:
            kernel_reduccion_desenrrollado_parcial<<<bloques_por_grid,hebras,sizeof(int)*bloques_por_grid>>>(device_vector, device_salida);
        break;

        case 3:
            kernel_reduccion_desenrrollado_total<<<bloques_por_grid,hebras,sizeof(int)*bloques_por_grid>>>(device_vector, device_salida);
        break;

    }

    tiempo = cpuSecond() - tiempo;

    cudaMemcpy(resultado, device_salida, bloques_por_grid*sizeof(int), cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();

    int max = maximo_local(resultado,bloques_por_grid);

    if(imprimir){
        cout << "Kernel: " << kernel << " Hebras: " << hebras << " Bloques: " << bloques_por_grid << "  Tiempo: " << tiempo << endl;
        cout << "El maximo obtenido al rellenar el ciclo es: " << maximo       << endl;
        cout << "El maximo obtenido al usar reduccion    es: " << max << endl;
    }else{
        cout << tiempo << " ";
    }

    /*
    Algoritmo secuencial
    double tiempo = cpuSecond();

    int max = maximo_local(vector,N);

    tiempo = cpuSecond() - tiempo;

    cout << tiempo << " ";
    */
    cudaFree(device_salida);
    cudaFree(device_vector);
    free(vector);
    free(resultado);

}
