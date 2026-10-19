
# Ejercicio 00 — Ética y responsabilidad profesional

**Curso:** Base de Datos Avanzadas y Big Data  
**Tema 01:** Fundamentos avanzados de bases de datos relacionales  
**Equipo:** Grupo 01  
**Integrantes:** Huari Llacza, Giancarlo Daniel | Chavez German, Luciana Salma | Larios Perez, Cesar Smith | Rondan Blas, Miguel Angel Yersyño 
**Fecha:** 19 - 10 -2026

## Paso 2. Dos situaciones reales

### Situación A. Clínica Delgado

**Fuente:** RPP, 17 de febrero de 2025.  
**Noticia:** 1616825 — Filtración de información médica.

**1. ¿Qué pasó?**  
La clínica reportó la filtración de información médica confidencial de una paciente a través de canales internos. La institución identificó a los responsables e inició un proceso sancionador, mientras Susalud intervino de oficio.

**2. ¿Quiénes resultaron afectados?**  
Principalmente la paciente, cuya privacidad e intimidad fueron expuestas. También la clínica, que enfrenta un proceso sancionador y una posible multa de 125 UIT por parte de la autoridad de salud.

**3. ¿Qué principio del Código de Ética del CIP se vulneró?**  
Se vulneró el principio de **Reserva de la información (Art. 45 c)**, al no mantener la debida confidencialidad de los datos conocidos por el trabajo. Asimismo, se afectó el **Servicio a la sociedad y seguridad (Art. 14 y 29)** al no garantizar la protección del paciente.

**4. ¿Qué control técnico habría reducido el riesgo?**  
El **Acceso por roles con privilegios mínimos**, para que solo el personal médico autorizado acceda a la historia clínica, complementado con un **Registro de auditoría de accesos** para rastrear quién consultó el dato.

**5. ¿Qué dato de la fuente no está confirmado?**  
No se confirma si la filtración fue un acto malicioso intencional de un empleado o una negligencia técnica. Tampoco se especifica si la paciente autorizó la difusión de su diagnóstico.

---

### Situación B. Base de datos atribuida al Minsa

**Fuente:** RPP, 18 de agosto de 2022.  
**Noticia:** 1425567 — Venta de datos privados de pacientes.

**1. ¿Qué pasó?**  
Un hacker puso a la venta en un foro de internet una base de datos atribuida al Minsa con información de 44 mil pacientes. Los datos incluían nombres, DNI, historias clínicas y domicilios actualizados hasta marzo de 2022.

**2. ¿Quiénes resultaron afectados?**  
Los 44 mil pacientes cuyos datos personales y de salud fueron expuestos. Esto los deja vulnerables a delitos como extorsión, fraudes financieros o discriminación por sus antecedentes médicos.

**3. ¿Qué principio del Código de Ética del CIP se vulneró?**  
Se vulneró la **Diligencia técnica (Art. 19)**, por la falta de medidas de seguridad robustas para proteger los sistemas. Además, se quebrantó la **Reserva de la información (Art. 45 c)** al permitir que datos sensibles de ciudadanos queden a disposición de terceros.

**4. ¿Qué control técnico habría reducido el riesgo?**  
El **Cifrado y respaldo protegido** de la base de datos (tanto en reposo como en tránsito) para que, en caso de robo, la información sea ilegible. También la **Minimización de campos**, evitando almacenar datos que la tarea administrativa no requiere.

**5. ¿Qué dato de la fuente no está confirmado?**  
No se confirma si los 44 mil registros son reales o si el hacker logró concretar la venta de la base de datos. Tampoco se esclarece si la extracción fue por un ataque externo o por un acceso indebido interno.

---

## Paso 3. Un dilema, una decisión

**Instrucción:** Elijan solamente uno de los dilemas.

### Dilemas disponibles

**Dilema 1:** El jefe solicita incluir el nombre y DNI del paciente en los mensajes de error para encontrarlo más rápido.

**Dilema 2:** Una atención registra 240 minutos. El director quiere eliminarla porque altera el promedio, pero no se sabe si es un error o un caso real.

### Respuesta del equipo

**Dilema elegido:** 1

**Línea 1 — Decisión:**  
Nos negamos a incluir datos personales en los mensajes de error; en su lugar, programaremos el sistema (usando TRY...CATCH) para que muestre solo el ID interno de la transacción o un código genérico de error.

**Línea 2 — Principio ético:**  
**Reserva de la información (Art. 45 c)** y **Veracidad (Art. 27 a)**. El profesional debe mantener la reserva de los datos y no exponer información sensible en logs o pantallas a las que otros usuarios puedan acceder.

**Línea 3 — Consecuencia:**  
Beneficia directamente a los pacientes al proteger su privacidad e intimidad. Afecta operativamente al área de TI y al jefe, quienes deberán buscar los errores por el ID del sistema en lugar de por el DNI, pero garantiza el cumplimiento de la Ley de Protección de Datos Personales.



