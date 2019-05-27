def calcular_media(vector_datos):
    suma = 0.0

    for dato in vector_datos:
        if dato > 0:
            suma += dato

    media = (suma)/len(vector_datos)

    return media


completo = open('desenrrollado_completo.time',mode='r', encoding='utf-8')
parcial = open('desenrrollado_parcial.time',mode='r', encoding='utf-8')
secuencial = open('kernel_reduccion_secuencial.time',mode='r', encoding='utf-8')
intervalos = open('kernel_reduccion_intervalos.time',mode='r', encoding='utf-8');
cpu = open('secuencial.time',mode='r', encoding='utf-8')

completo = completo.read()
parcial = parcial.read()
secuencial = secuencial.read()
intervalos = intervalos.read()
cpu = cpu.read()

cpu = cpu.split(' ')
completo = completo.split(' ');
parcial = parcial.split(' ');
secuencial = secuencial.split(' ');
intervalos = intervalos.split(' ');

cpu.pop(len(cpu)-1)
completo.pop(len(completo)-1)
parcial.pop(len(parcial)-1)
secuencial.pop(len(secuencial)-1)
intervalos.pop(len(intervalos)-1)

completo_float = []
parcial_float = []
secuencial_float = []
intervalos_float = []
cpu_float = []

for item in completo:
    completo_float.append(float(item))

for item in parcial:
    parcial_float.append(float(item))

for item in secuencial:
    secuencial_float.append(float(item))

for item in intervalos:
    intervalos_float.append(float(item))

for item in cpu:
    cpu_float.append(float(item))

media_completo = calcular_media(completo_float)
media_parcial = calcular_media(parcial_float)
media_secuencial = calcular_media(secuencial_float)
media_intervalos = calcular_media(intervalos_float)
media_cpu = calcular_media(cpu_float)

print("Speed up Secuencial vs desenrrollado completo:   " + str(media_cpu/media_completo))
print("Speed up Secuencial vs desenrrollado parcial:    " + str(media_cpu/media_parcial))
print("Speed up Secuencial vs reduccion secuencial:     " + str(media_cpu/media_secuencial))
print("Speed up Secuencial vs reduccion por intervalos: " + str(media_cpu/media_intervalos))

print("Tiempo CPU: " + str(media_cpu))
print("Tiempo media_secuencial: " + str(media_secuencial))
print("Tiempo media_intervalos: " + str(media_intervalos))
print("Tiempo media_parcial: " + str(media_parcial))
print("Tiempo desenrrollado completa: " + str(media_completo))


print("Completo vs parcial: " + str(media_parcial/media_completo))
print("Intervalos vs secuencial: " + str(media_secuencial/media_intervalos))
