La aplicación de mantenimiento por el momento tiene 2 módulos:
- Generación de reportes preventivos
- Generación de reportes correctivos

Estos 2 módulos son los actuales pero se prevee crear más módulos para más adelante. Es una aplicación para el área de mantenimiento, los reportes preventivos y correctivos ya tienen su propio formato, pero cada uno de estos tiene sus características según sus equipos, pero para antes de explicar cómo funcionan los reportes, primero se tiene que explicar como funciona todo acá:

El proyecto actual es el proyecto de mantenimiento de metro lima linea 2, pero se prevee poder usar esta aplicación en otros proyectos como por ejemplo metro lima linea 1 o proyecto de madrid linea 1, por lo que debe ser variable esto por lo que ya se tiene campos como Sede, Proyecto, Etapa (metro lima linea 2 tiene etapa 1A, 1B, 2A, etc..). En cada uno de estos proyectos se prevee usar la aplicación en distintos usos, en este caso es de mantenimiento señalización pero puede ser usado por ejemplo en mantenimineto infraestructura o civil o redes, puede ser distintos valores pero por ejemplo por ahora se tiene Sistema "Señalización" por el momento. Esto anterior es la clave lo cuál guiará la aplicación en qué modulos usar o mostrar al usuario ya que por el momento los 2 módulos actuales de reportes preventivos y correctivos están en el sistema de señalización en metro lima linea 2. Después los sistemas tienen subsistemas por ejemplo en señalización existe ATS, IXL, CBTC, etc. 

Ahora como parte de un equipo de mantenimiento, se ve distintos equipos, componentes, herramientas, etc. Por ejemplo en nuestros sistemas hay varios servidores, hay servidores que son varios CPUs que están dentro de un gabinete entero o hay otros gabientes que en vez de estar llenos de servidores, está lleno de tarjetas que funcionan de manera full analógica, no solo se ve gabinetes sino que también equipos en vía como cambia vías, circuito de vías, es decir hay bastantes equipos y componentes que se ven en los mantenimientos y también que se poseen, cada uno en ubicaciones distintas como salas técnicas, salas de señalización, estaciones, vías, patio abierto, hay varias ubicaciones y cada equipo grande (por ejemplo un tren) por dentro tiene también equipos como por ejemplo el tren tiene un CC que vienen a ser gabinetes y cada gabinete tiene tarjetas y ventiladores. Como ves hay varias cosas en distintos tamaños de distintas maneras y distintas ubicaciones.

Te listaré a continuación de los más importantes:
1. Ejemplo 1
Equipo Grande: Tren 14
Tipo de equipo: Tren
Tren 14 no tiene un número serial
Subsistema al que pertenece: CBTC
Ubicaciones dentro del tren: Coche M1, M2, S1, S2, R1, R2
Equipos pequeños que tiene dentro el equipo grande (tren): CC, BTM, TOD, etc
La ubicación del CC es en el coche R1
Tipo de equipo del CC: Cargo Controller
CC no tiene número serial, pero sus 2 gabinetes sí tienen, cada uno.
CC dentro tiene 2 gabinetes.
Equipos más pequeños dentro de equipos pequeños (CC, gabinete 1): SCCR A, SCCR B, TIR A, TIR B, etc (cada uno de estos tiene part number y serial number)
Equipo mucho más pequeño o componentes dentro de equipos más pequeños (SCCR A): ACSDVP 11, CCTE 1, CBOP 1, etc (Estos son los equipos o componentes atómicos, es decir ya no hay más dentro de estos, y cada uno de estos tiene part number y serial number)

2. Ejemplo 2
Equipo Grande: CRK 1 (Es el nombre específico de n gabinete)
Tipo de equipo: Gabinete
CRK 1 tiene un número serial y part number
Subsistema al que pertenece: ATS
Ubicaciones dentro del gabinete: Puerta frontal, puerta posterior e interior del gabinete.
Equipos dentro del interior del gabinete: LIMSYS001, LIMSYS002, LIMCOM001, etc (Estos son los equipos o componentes atómicos, es decir ya no hay más dentro de estos y cada uno de estos tiene su part number y serial number)
Tipo de equipo de LIMSYS001: Servidor
Ubicación LIMSYS001: A

3. Ejemplo 3
Equipo Grande: Tren 26
Tipo de equipo: Tren
Subsistema al que pertenece: CBTC
Ubicaciones dentro del tren: Coche M1, M2, S1, S2, R1, R2
Equipos pequeños que tiene dentro el equipo grande (tren): CC, BTM, TOD, etc
La ubicación del TOD es en el coche M1
Tipo de equipo del TOD: Equipo interfaz
El TOD ya no tiene más componentes o equipos pequeños dentro, este es el atómico y tiene su part number y serial number.

4. Ejemplo 4
Equipo Grande: Zone Controller 4 (Tiene su número serial)
Tipo de equipo: Gabinete
Subsistema al que pertenece: CBTC
Ubicaciones dentro del FRONTAM: Puerta frontal, puerta trasera y cubículo o interior del gabinete.
Equipos pequeños del FRONTAM cubículo: Ventilador superior, Fuente de poder-230V, PC SILAM 2, PC SILAM 1, KVM, Ventilador medio, PCSG 1, PCSG 2, PCSG 3, Ventilador inferior (cada uno tiene part number y número serial, pero algunos solo tienen part number)
Ubicación del PCSG 1: PCSG 1
Tipo de equipo del PCSG 1: Servidor
Equipos pequeños dentro del PCSG: MVME 1, CME 1, CCS-V 1, CIER 1, CALS 1 (Cada uno de estos tiene part number y serial number)
Tipo de equipo o componente de CIER 1: Tarjeta (El CIER ya es el más atómico, ya no hay nada dentro de este)
Ubicación del CIER 1: CIER 1 1

Como puedes ver en lo anterior cada "equipo grande" tiene distintos niveles de profundidad o ramas viendolo como si fuera un árbol, y cada uno tiene un número distinto de hojas que puede aceptar este equipo. Cada equipo o componente es de algún tipo y también los equipos pequeños tienen una ubicación con el equipo padre, casi siempre hay un equipo/componente padre - hijo y siendo el padre el componente hijo de algún otro componente padre (o equipo), por lo que cada equipo o componente tiene una ubicación o slot dentro de otro equipo, los componentes padres primarios son los que no tienen un slot dentro de otro equipo ya que son los primeros, ellos no tienen padre, pero sí casi todos los "Equipo padre" (como el zone controller 4, el CRK 1, etc) tienen una localización fija, a excepción de los trenes ya que estos paran de lugar en lugar pero con respecto a los otros componentes padre ya se sabe en donde están, en qué proyecto, en qué estación, en qué sala técnica, o si no es en una estación entonces es en un túnel y fragmento de tunel estación 1 - estación 2, los equipos pequeños o componentes su localización no sería tanto como estación/túnel, sino que sería ubicación de equipo padre, tarjeta CIER 1 de serial number XYZ se localiza en Zone Controller 3 por ejemplo. También existen software que en vez de componentes que tienen marca y serial number, estos software tienen versión, estos software generalmente pertenecen a servidores, por ejemplo software ATS pertenece al servidor LIMSYS001. También cabe aclarar que hay equipos que son un tipo de equipo específico por ejemplo los servidores ATS son el mismo servidor (tienen el mismo part number, pero distinto número serial), de misma manera los equipos pequeños o componentes como la tarjeta CIER, existen varias entre los trenes, por lo que todas las tipo CIER tienen el mismo part number pero distinto número serial. El número serial es el ID de cada equipo o componente y el part number es el ID de cada tipo de equipo o componente.

El tema de equipos es complejo ya que son árboles de equipos con distintos niveles y ubicaciones cada uno. Pero explicado eso ya puedo entrar por fin a los módulos, primero sería el módulo de generación de reportes de mantenimiento preventivo:

- Modulo generación de reportes de mantenimiento preventivo
Generalmente y casi siempre los mantenimientos preventivos se hacen para un o varios equipos grandes. Por ejemplo se hace mantenimiento a un tren como al tren 14, allí está ligada directamente el tren con el mantenimiento, pero por ejemplo el CRK1 y 2 a pesar de ser distintos equipos grandes también es un mantenimiento, en este caso CRK1 y 2 están ligados al mismo mantenimiento, hay mantenimientos como inspección de FRONTAM que está ligado también directamente a un solo equipo padre que viene a ser el FRONTAM, otro ejemplo es limpieza de estación de trabajo FRONTAM, este es un mantenimiento a la computadora del FRONTAM el cual contiene monitor, CPU y teclado, estos son componentes de una misma workstation pertenecen al equipo padre de estación de trabajo, otro ejemplo es el mantenimiento preventivo de software ats, este es un mantenimiento hacia el propio software de ats y se hace sobre el software dentro de servidores por ejemplo una actividad de mantenimiento de software se hace sobre el servidor LIMSYS001, LIMSYS002, LIMCOM001, LIMCOM002, LIMCWS001, etc, una sola actividad puede darse en un equipo grande o en muchos pequeños o en muchos grandes. Cada actividad está ligada a una ubicación específica, por ejemplo un tipo de mantenimiento hacia el gabinete frontam puede ser hecho en patio o en colectora por lo que acá son 2 actividades de mantenimiento frontam en patio y en colectora. Por lo que una actividad está ligada a una o varios equipos grandes o equipos pequeños, pero siempre está relacionado a algún equipo ya sea padre o hijo y también la actividad está ligada a una ubicación específica casi todas las actividades tienen una ubicación por default, como ya se te explicó anteriormente: El gabinete llamado frontam (equipo padre original) está en 2 ubicaciones (patio y estación colectora), cada gabinete tiene la misma arquitectura (ventiladores, 2 servidores tipo app, 1 servidor tipo db) pero claro cada uno de estos equipos es diferente (es decir tiene número serial distinto). Cada mantenimiento tiene 1 manual al que se le sigue, el manual tiene toda la información de mantenimiento, el procedimiento y las herramientas que se deben usar. También cada actividad es un tipo de actividad específica (inspección, limpieza, Cambio de componente, etc), también cada mantenimiento se relaciona con un subsistema, cada mantenimiento puede tener varias herramientas predefinidas a usarse, como también la cantidad de mantenedores predefinidos que se necesitan, cada actividad tiene un procedimiento, es decir se tiene una serie de pasos que se debe seguir para realizarlo, cada paso también puede llamarse tarea a realizar en el mantenimiento, cada paso o tarea puede tener 1 o n resultados, por ejemplo puede ser una tarea nivelar el nivel de aceite en el cambia vía, los resultados predefinidos que se tiene en el dropdown del frontend es "Nivel óptimo al iniciar el mantenimiento", "Se niveló el aceite porque faltaba" o "Nivel no óptimo de aceite, faltaba aceite", pero esta tarea o paso solo puede tener 1 resultado de todos los posibles como por ejemplo "Nivel óptimo al iniciar el mantenimiento", pero puede haber otros pasos o tareas que pueden tener varias pruebas dentro del paso o tarea, por ejemplo hay otro paso que se llama verificar ping de los servidores, en este paso se verifica en 5 servidores si hay ping, en cada uno de estos se prueba el ping por lo que cada uno de estos servidores tiene 1 resultado, por ejemplo el servidor 1 como posibles resultados pueden ser "Ping con exito" o "Ping sin exito", pero también el servidor 2 puede tener posibles resultados como  "Ping con exito" o "Ping sin exito", por lo que el resultado del servidor 1 puede ser Ping con exito, el resultado del servidor 2 puede ser Ping sin exito, etc. En resumen cada actividad de mantenimiento tiene n pasos o tareas y cada tarea tiene n pruebas, cada prueba tiene 1 resultado, también en el reporte cada paso o tarea tiene un comentario que se puede añadir pero esto ya es opcional por usuario. Cada actividad lo pueden hacer n mantenedores. Cada reporte es acerca un mantenimiento, por ejemplo mantenimiento de inspección de gabinete ERK 1 y 2 en estación colectora, un mantenimiento puede tener N reportes (ya sea porque se quiso editar el reporte y se hizo una versión 2 o porque se hace a lo largo del año), por ejemplo mantenimiento de puestos perifericos es una vez al mes, mantenimiento de trenes es cada 6 meses. En el mantenimiento se pueden usar n herramientas y n equipos especializados de medición, cada reporte tiene n trabajadores tanto nombre, como cargo y su firma. Cada reporte tiene metadata de lugar donde se hizo el mantenimiento, la fecha, hora, proyecto. También cada reporte tiene los pasos que se tiene que hacer en el mantenimiento con las n pruebas que tiene cada paso, el resultado y el comentario. Cada reporte tiene su conclusión y sus comentarios adicionales y finalmente también cada reporte tiene sus imágenes anexadas. Cada mantenimiento preventivo tiene su descripción de que realizar, como también las actividades realizadas anteriormente (meses anteriores) como su histórico de mantenimientos anteriores como también los mantenimientos que están más adelante programados.

- Modulo generación de reportes de mantenimiento correctivos:
El mantenimiento preventivo es algo que sucede cada cierto tiempo con una programación de actividades, pero el correctivo es algo que sucede de la nada sin previo aviso, para estos correctivos es un poco más sencillo y abierto que los preventivos porque no se tiene un procedimiento como tal, los reportes de mantenimiento correctivo también tienen N reportes sobre un evento (n porque se pueden ir haciendo reportes entre los turnos de los trabajadores), puede tener información sobre el lugar donde ocurrió el evento, sobre qué equipo ocurrió, la hora de ocurrencia y de inicio de mantenimiento, el código de sap, el subsistema, descripciones del problema ocurrido, el tipo de falla, también este reporte tiene las n tareas o pasos que se hicieron pero de manera general sin tener alguna bd sobre esto, comprende el tipo de tarea o paso (esto sí está definido directamente desde db) y según el tipo de tarea se puede almacenar simplemente una descripción de lo realizado o por ejemplo si el tipo de tarea es "cambio de componente o equipo", entonces aquí es más complejo porque se tiene que guardar el equipo que se sacó a donde se llevó y el equipo que se repuso de donde se sacó, los numeros seriales y part number de cada uno, también este intercambio tiene que reflejar por detrás si este equipo intercambiado era hijo de otro equipo, entonces se tiene que actualizar que ahora este equipo repuesto es el nuevo hijo. El reporte correctivo también tiene las herramientas usadas como también , imágenes subidas del mantenimiento y más campos adicionales de metadata como también informativos, también imágenes y trabajadores que participaron. Cada evento guarda un registro como timeline de todo lo hecho y también todo el log de reportes generados durante el tiempo.

Lo anterior comprende todo relacionado a la aplicación que se quiere construir, es algo general acerca del los módulos actuales en mantenimiento, se prevee que haya más en el futuro. Sobre lo anterior cómo se podría armar el diagrama ER de todo lo que abarca los mantenimientos. Dame un diagrama ER en formato markdown fácil de entender y que también pueda servir de prompt para que otra IA la pueda entender.


We now have additional operational and business information that was missing from the previous iterations of the domain model, architecture, engineering guide, and product specification.

This new information is extremely important because it affects:

* domain modeling,
* report aggregates,
* workflow orchestration,
* PDF generation,
* UI/UX flows,
* dynamic forms,
* hierarchy modeling,
* attachment handling,
* maintenance traceability,
* offline continuity,
* and potentially notification/email capabilities.

Your task is to carefully analyze all the information below and apply the necessary updates across ALL previously created documents, including but not limited to:

* domain-model.md
* architecture.md
* engineering-guide.md
* product-spec.md
* ADR candidates (if needed)

IMPORTANT:
Do NOT remove existing information unless it directly conflicts with the new requirements.
The objective is to evolve and refine the existing design, not restart it.

Also:

* identify new entities,
* identify missing relationships,
* identify missing invariants,
* identify missing workflows,
* identify missing UI states,
* identify missing bounded-context interactions,
* identify missing temporal/history concerns,
* identify missing reporting requirements,
* and identify potential scalability or UX risks.

If any requirement is ambiguous, inconsistent, or incomplete, ask clarification questions before making assumptions.

# IMPORTANT CONTEXT

The application has two primary operational modules:

1. Preventive Maintenance
2. Corrective Maintenance

Both modules revolve around the creation and lifecycle of operational maintenance reports.

The report is the central operational artifact.

The application is used by railway signaling maintenance personnel in real operational environments.

The current system exists in Power Apps, but the new iOS app and backend are a complete redesign and should NOT replicate the Power Apps architecture or database model.

The old Power Apps implementation should only be treated as operational/business reference material.

# PART 1 — PREVENTIVE MAINTENANCE REPORT

## Preventive Report — App Form Data

The preventive report form currently includes:

### General Context

* Site (default: Site Lima)
* Project (default: Metro Línea 2)
* Stage (default: Etapa 1A - Línea 2)
* System (default: Señalización)

These values are currently fixed/default because the application is initially scoped to the current railway signaling project.

### Maintenance Metadata

* Equipment Category

  * Large category grouping for assets
  * Examples:

    * Cabinet
    * Trackside equipment
    * Vehicle

* Work Order

  * Weekly maintenance work code

* SAP Order

  * SAP notification/order code

* Personnel

  * Workers participating in the maintenance

* Maintenance Date

* Start Time

* End Time

### Asset Selection

* Equipment

  * Filtered by equipment category

* Maintenance Template / Maintenance Type

  * Available maintenance procedures for the selected equipment

### Geographic / Operational Area

* AreaN1

  * Top-level area
  * Examples:

    * Patio
    * Tunnel
    * Station

* AreaN2

  * Child area
  * Examples:

    * Patio Santa Anita
    * Tunnel Hermilio Valdizán-Colectora
    * Estación Colectora

### Tools

* Tools used during maintenance

### Maintenance Task List

The maintenance procedure contains a list of predefined tasks/steps.

Each step includes:

#### Action 1 — Completion Checkbox

* Checked = task performed
* Unchecked = task not performed
* Tasks are checked by default

#### Action 2 — Open Manual Reference

* Opens the specific PDF page from the maintenance manual corresponding to that step

#### Action 3 — Open Tests Popup

A popup containing:

* one or many tests,
* test results,
* comments/notes.

Each task may have:

* 1..N tests
* 1..N possible test result values

### Attachments

* Take photos
* Upload images from gallery/library

### Email Sending

Potential capability:

* send report email to:

  * entire team
  * only current user

You must evaluate whether this should become:

* backend email orchestration,
* async background job,
* or client-side share functionality.

### Final Result

* Equipment operational
* Equipment partially operational
* Equipment non-operational

### Additional Comments

Free text notes/comments.

# Preventive Report — Database Metadata

In addition to form data, the database persists:

* real creation timestamp,
* real completion timestamp,
* creator user,
* creator email,
* audit metadata.

# Preventive Report — PDF Output

The final PDF contains:

## Page 1

* Company logo
* Contract number
* Preventive report format code
* Revision/version
* Current page / total pages
* Contractor
* Contract name
* Maintenance date
* Start/end times
* Subcontractor
* Stage
* Technology
* Geographic area/location
* Reference manual
* SAP order
* Activity type and subsystem

### Personnel Table

Columns:

* Personnel role/type
* Number of persons
* Total hours

### Tools Table

Columns:

* Tool/equipment
* Serial number
* Total hours

### Activity Information

* Activity name
* Activity frequency

### Maintenance Steps Table

Columns:

* Item
* Task description
* Approval status

  * OK
  * N/A
* Result

  * concatenated test results
* Task comments

### Final Maintenance Result

* Conclusion
* Additional comments

### Personnel Signature Table

Columns:

* Maintainer name
* Maintainer role
* Signature
* Signature date

## Pages 2..N

Maintenance images/attachments.

# PART 2 — CORRECTIVE MAINTENANCE REPORT

The corrective report is significantly more complex and may require substantial model updates.

## Corrective Report — General Sections

The corrective report is composed of multiple progressive sections.

Several sections include a workflow feature:

### "Stop Here" Indicator

The technician may intentionally stop the report at a given section because the corrective work was not finished during the current shift.

If activated:

* subsequent sections become hidden,
* except:

  * attachments,
  * email sending.

This implies:

* partial report lifecycle support,
* resumable workflows,
* draft continuation,
* progressive completion states.

You must evaluate:

* lifecycle states,
* UX implications,
* offline implications,
* temporal persistence implications.

## Corrective Report — Section 1 — General Information

Includes:

* Site
* Project
* Stage
* System

(default values as in preventive)

### Asset Hierarchy Selection

* Subsystem
* Equipment Category
* Equipment

### Geographic Hierarchy

* AreaN1
* AreaN2
* AreaN3
* AreaN4

IMPORTANT:

Areas themselves are hierarchical structures and should likely become first-class entities instead of flat fields.

Example hierarchy data:

(Examples omitted here for brevity — preserve them structurally in the updated documents.)

You must evaluate whether:

* Area should become a recursive aggregate/entity,
* AreaAssignment should exist,
* or whether Area is a taxonomy hierarchy.

### SAP/Event Metadata

* SAP Event Name
* SAP Notification
* Notification Creation Date
* Notification Creation Time
* Response Date
* Response Time

### Participants

Workers participating in maintenance.

## Corrective Report — Section 2 — Signaling Asset

* subsystem
* equipment category
* equipment
* critical element (yes/no)

## Corrective Report — Section 3 — Failure Description

* recorded symptom
* detailed technical description
* operational impact

## Corrective Report — Section 4 — Failure Analysis

* failure type

  * functional
  * software
  * hardware
  * etc.

You should evaluate whether:

* failure taxonomy entities are needed,
* or enums are sufficient for v1.

## Corrective Report — Section 5 — Corrective Activities

This section is dynamic.

The number of activities/steps is unknown beforehand.

Each activity has two possible structures.

## Type A — Standard Activity

Fields:

* activity type
* service start date
* service start time
* description
* service end date
* service end time

## Type B — External Component Replacement

This is extremely important because it deeply affects:

* asset hierarchy,
* asset replacement,
* traceability,
* warehouse/inventory integration,
* temporal assignment modeling.

### Removed Component Segment

The technician must select the component being removed.

Selection methods:

1. Search

   * serial number
   * component name

2. Recursive hierarchy navigation

Example:
Train
→ Cars
→ Equipment
→ Cabinet
→ Rack
→ Component

The hierarchy can traverse until leaf components.

The technician may:

* select intermediate component,
* or continue traversing deeper.

Once selected:

* component metadata auto-loads:

  * part number
  * serial number
  * model
  * manufacturer
  * status

Additional fields:

* destination after removal

  * SPV warehouse
  * maintenance storage
  * etc.
* notes

### Installed Component Segment

Fields:

* source warehouse or source asset
* component search
* selected component metadata
* notes

This also introduces:

* cross-asset component movement,
* asset cannibalization scenarios,
* warehouse traceability,
* asset-to-asset transfer scenarios.

These workflows must be reflected in:

* domain model,
* aggregate orchestration,
* history tracking,
* and UI flows.

## Corrective Report — Section 6 — Operational Validation

Fields:

* functional tests performed
* result
* release for service
* release date
* release time
* validation responsible

## Attachments

Corrective report also supports:

* camera capture,
* image upload,
* image persistence,
* attachment visualization.

## Final Results

* technical equipment status
* comments

## Email Sending

Same requirement as preventive.

Evaluate architecture and UX implications.

# Corrective Report — Database Metadata

Persist:

* creation timestamps,
* completion timestamps,
* creator identity,
* audit metadata,
* progression state,
* draft continuation metadata.

# Corrective Report — PDF Output

The corrective PDF contains:

* title
* creation date
* report code
* generated report number
* general data
* signaling asset
* failure description
* failure analysis
* corrective activities table
* affected/replaced components table
* operational validation
* maintenance timing metrics
* final results
* maintainers table
* signatures
* report creator
* report creation date

You must evaluate whether:

* dedicated PDF composition services,
* template engines,
* or report-generation pipelines
  should be introduced in architecture documents.

# REQUIRED TASKS

Please update all relevant documents with:

1. domain model updates,
2. aggregate changes,
3. entity additions,
4. workflow updates,
5. UI/UX updates,
6. API updates,
7. PDF generation architecture,
8. offline/draft flow updates,
9. attachment architecture updates,
10. report lifecycle changes,
11. event model changes,
12. inventory integration implications,
13. area hierarchy implications,
14. notification/email implications,
15. testing implications,
16. temporal traceability implications.

# IMPORTANT

Do NOT oversimplify the problem.

But also:

* do NOT overengineer for v1.
* preserve the modular monolith strategy.
* preserve implementation pragmatism.

Prioritize:

* operational usability,
* maintainability,
* traceability,
* extensibility,
* and clean domain boundaries.

# ADDITIONAL CONTEXT

I will also provide examples of the current Power Apps tables so you can use them as operational reference material.

IMPORTANT:
These tables are ONLY references for:

* naming,
* operational semantics,
* relationships,
* real-world usage patterns.

The new backend/domain model MUST NOT mirror the Power Apps schema directly.
It should remain aligned with the new domain-driven architecture already designed.
The following are the tables that we are using in power apps:

las tablas usadas en el proyecto actual son:

tbl_Area: Areas y tipos de areas en los mantenimientos por el momento
ID_Area	AreaN1	AreaN2	AreaN3	AreaN4
1	Patio	Patio Santa Anita	Área técnica	PCON
2	Estación	Colectora Industrial (PL22)	Área técnica	PCOE
3	Patio	Patio Santa Anita	Área técnica	Simulador
4	Patio	Patio Santa Anita	Área técnica	Sala señalización
5	Estación	Colectora Industrial (PL22)	Área técnica	Sala 2.21
6	Patio	Patio Santa Anita	Nave taller	TK
7	Estación	Colectora Industrial (PL22)	Área técnica	Sala 2.02
8	Patio	Patio Santa Anita	Área técnica	Sala mantenimiento
9	Estación	Mercado Santa Anita (PL24)	Área técnica	Sala 2.02
10	Estación	Hermilio Valdizán (PL23)	Área técnica	Sala 2.02
11	Estación	Óvalo Santa Anita (PL21)	Área técnica	Sala 2.02
12	Estación	Evitamiento (PL20)	Área técnica	Sala 2.02
13	Patio	Patio Santa Anita	Explanada	Vía principal
14	Túnel	Mercado Santa Anita (PL24)	Tramo Hermilio Valdizán - Mercado Santa Anita (T2HS)	Vía principal
15	Túnel	Hermilio Valdizán (PL23)	Tramo Hermilio Valdizán - Mercado Santa Anita (T2HS)	Vía principal
16	Túnel	Hermilio Valdizán (PL23)	Tramo Colectora Industrial - Hermilio Valdizán (T2CH)	Vía principal
17	Túnel	Óvalo Santa Anita (PL21)	Tramo Óvalo Santa Anita - Colectora Industrial (T2OC)	Vía principal
18	Túnel	Óvalo Santa Anita (PL21)	Tramo Evitamiento - Óvalo Santa Anita (T2EO)	Vía principal
19	Túnel	Evitamiento (PL20)	Tramo Evitamiento - Óvalo Santa Anita (T2EO)	Vía principal
20	Túnel	Mercado Santa Anita (PL24)	Tramo Mercado Santa Anita - Vista Alegre (T2SV)	Vía principal
21	Túnel	Colectora Industrial (PL22)	Tramo Colectora Industrial - Hermilio Valdizán (T2CH)	Vía principal
22	Túnel	Colectora Industrial (PL22)	Tramo Óvalo Santa Anita - Colectora Industrial (T2OC)	Vía principal
23	Túnel	Evitamiento (PL20)	Tramo San Juan de Dios - Evitamiento (T2DE)	Vía principal



tbl_Activity: actividades de mantenimiento (algunos mantenimientos agrupan varios equipos)
ID_Activity	ActivityN1	ActivityN2	ActivityN3_Resume	ActivityN3_Detail	ActivityN4	Report_Code	Subsystem	System	Manual_Ref	Manual_Ref_Link	PagManual_Ini	PagManual_End	Frequency	FK_Subsystem
1	Preventivo	Inspecciones / Levantamiento de Data	Mantenimiento preventivo de Software de ATS	"REVISIÓN DEL SISTEMA
Revisión de los archivos de registro del sistema.
Verificación del uso de la memoria.
Verificación del uso del espacio en disco.
Verificación de sistemas de archivos de solo lectura.
Verificación del estado NTP
Verificación de montajes NFS.
Verificación del estado de conexión de esclavos de vínculo.
Verificación del estado de la cola de impresión."	Código OT	Informe A1	ATS	Señalización	ML2-AST-GEN-G-000-GRAL-SSATS-GEN-MN-3500-0A	https://hitachigroupeur.sharepoint.com/sites/l2-mantenimientosealizacin/shared%20documents/ats/manuales/ml2-ast-gen-g-000-gral-ssats-gen-mn-3500-0a.pdf	85	89	Revisión periódica diaria	2
2	Preventivo	Inspecciones / Levantamiento de Data	Simulador de ATS	"REVISIÓN DEL SISTEMA
-Revisión de los archivos de registro del sistema.
- Verificación del uso de la memoria.
- Verificación del uso del espacio en disco.
-  Verificación de sistemas de archivos de solo lectura."	Código OT	Informe A1S	ATS	Señalización	ML2-AST-GEN-G-000-GRAL-SSATS-GEN-MN-3500-0A	https://hitachigroupeur.sharepoint.com/sites/l2-mantenimientosealizacin/shared%20documents/ats/manuales/ml2-ast-gen-g-000-gral-ssats-gen-mn-3500-0a.pdf	85	89	Revisión periódica mensual	2
3	Preventivo	Inspecciones / Levantamiento de Data	Gabinete Inspección - ERK	INSPECCIÓN VISUAL DE GABINETES Y SERVIDORES (inspección visual de daños o desconexiones detectables a simple vista, inspección de polvo y/o suciedad) 	Código OT	Informe A2	ATS	Señalización	-	-	0	0	Revisión periódica bimestral	2
4	Preventivo	Limpieza	Gabinete mantenimiento - ERK	"INSPECCIÓN VISUAL Y LIMPIEZA de SERVIDORES Y GABINETES (LIMPIEZA interna Y externa de GABINETES, LIMPIEZA externa de SERVIDORES)
LIMPIEZA Y/O REEMPLAZO de FILTROS de AIRE de GABINETES"	Código OT	Informe A3	ATS	Señalización	-	-	0	0	Revisión periódica bimestral	2
5	Preventivo	Inspecciones / Levantamiento de Data, Limpieza	Mantenimiento preventivo de equipo a bordo CC - Tren	"INSPECCIÓN / COMPROBACIÓN / LIMPIEZA de PARTES del CC
INSPECCIÓN / COMPROBACIÓN / de CAJA BTM
INSPECCIÓN / COMPROBACIÓN / de ANTENA del LECTOR de ETIQUETAS
INSPECCIÓN / COMPROBACIÓN / SENORES de VELOCIDAD
INSPECCIÓN / COMPROBACIÓN / del TOD
Verificación PERIODICA  / ACELERÓMETRO
PRUEBA de DISYUNTORES del CC"	Código OT	Informe C1	CBTC	Señalización	ML2-AST-GEN-G-000-GRAL-SSCBT-GEN-MN-1546-0D	https://hitachigroupeur.sharepoint.com/sites/l2-mantenimientosealizacin/shared%20documents/cbtc/manuales/ml2-ast-gen-g-000-gral-sscbt-gen-mn-1546-0d.pdf	90	131	Revisión periódica semestral	3
6	Preventivo	Inspecciones / Levantamiento de Data	Inspección periódica de Zone Controller	INSPECCIÓN PERIÓDICA DE ZC	Código OT	Informe C2	CBTC	Señalización	ML2-AST-GEN-G-000-GRAL-SSCBT-GEN-MN-1547-0E	https://hitachigroupeur.sharepoint.com/sites/L2-Mantenimientosealizacin/Shared%20Documents/CBTC/Manuales/ML2-AST-GEN-G-000-GRAL-SSCBT-GEN-MN-1547-0D.pdf	62	62	Inspección periódica bimensual	3
7	Preventivo	Limpieza	Limpieza periódica del Zone Controller	"LIMPIEZA PERIÓDICA DEL ZC  (CUBICULO, CABLEDO, PARTES… ),
LIMPIEZA DE CONSOLA Y CONMUTADOR KVM,
LIMPIEZA Y/O REEMPLAZO DE FILTROS DE AIRE
LIMPIEZA DE LOS RACKS DE VENTILADORES"	Código OT	Informe C3	CBTC	Señalización	ML2-AST-GEN-G-000-GRAL-SSCBT-GEN-MN-1547-0E	https://hitachigroupeur.sharepoint.com/sites/L2-Mantenimientosealizacin/Shared%20Documents/CBTC/Manuales/ML2-AST-GEN-G-000-GRAL-SSCBT-GEN-MN-1547-0D.pdf	62	68	Mantenimiento periódica semestral	3
8	Preventivo	Inspecciones / Levantamiento de Data, Limpieza	Inspección periódica de Frontam y limpieza externa	INSPECCIÓN PERIÓDICA DE FTM Y LIMPIEZA EXTERNA DEL GABINETE	Código OT	Informe C4	CBTC	Señalización	ML2-AST-GEN-G-000-GRAL-SSCBT-GEN-MN-1548-0D	https://hitachigroupeur.sharepoint.com/sites/l2-mantenimientosealizacin/shared%20documents/cbtc/manuales/ml2-ast-gen-g-000-gral-sscbt-gen-mn-1548-0d.pdf	40	40	Inspección periódica trimestral	3
9	Preventivo	Limpieza	Limpieza interna del gabinete Frontam	"LIMPIEZA INTERNA DEL GABIENTE FTM ( CUBÍCULO, CABLEDO, PARTES… )
LIMPIEZA PERIÓDICA DE RACK DE VENTILADORES
LIMPIEZA Y/O REEMPLAZO DE FILTROS DE AIRE
LIMPIEZA DE CONSOLA Y CONMUTADOR KVM"	Código OT	Informe C5	CBTC	Señalización	ML2-AST-GEN-G-000-GRAL-SSCBT-GEN-MN-1548-0D	https://hitachigroupeur.sharepoint.com/sites/l2-mantenimientosealizacin/shared%20documents/cbtc/manuales/ml2-ast-gen-g-000-gral-sscbt-gen-mn-1548-0d.pdf	40	45	Mantenimiento periódico semestral	3


tbl_Proyect: tabla del proyecto y teapa con subsistema
Site	Proyect	Phase	System	Subsystem	ID_Proyect	FK_Subsystem	FK_Stage
Lima	METRO LÍNEA 2	Etapa 1A - Línea 2	Señalización	ATS	1	2	1
Lima	METRO LÍNEA 2	Etapa 1A - Línea 2	Señalización	CBTC	2	3	1
Lima	METRO LÍNEA 2	Etapa 1A - Línea 2	Señalización	IXL	3	1	1
Lima	METRO LÍNEA 2	Etapa 1B - Línea 2	Señalización	SIG	4	4	2
Lima	METRO LÍNEA 2	Etapa 2 - Línea 2	Señalización	SIG	5	4	3
Lima	METRO LÍNEA 2	Etapa 2 - Línea 4	Señalización	SIG	6	4	4


tbl_Equipment_Category: tabla de categoría de equipos
ID_Equipment_Category	EquipmentN1	EquipmentN2	FK_Subsystem
1	Software	Software ATS	2
2	Estación de trabajo	Simulador	2
3	Gabinetes	ATS	2
4	Vehículo	Tren	3
5	Gabinetes	ZC	3
6	Gabinetes	Frontam	3
7	Estación de trabajo	Frontam	3
8	Gabinetes	Puesto central IXL	1
9	Gabinetes	Puestos periféricos	1
10	Equipo de vía	Máquinas de conmutación	1
11	Equipo de vía	Circuito de vía	1
12	Gabinetes	Puestos periféricos Rele	1

tbl_Equipment_Kind: tabla de tipo de equipo
ID_EquipmentKind	Description
1	Tren
2	Gabinete PP Tipo 15
3	Gabinete ZC
4	Software ATS
5	Estación de trabajo
6	Gabinete ATS - CRK
7	Gabinete Frontam
8	Puesto central IXL VHMI
9	Puesto central IXL WSP
10	Puesto central IXL SIR
11	Gabinete PP Tipo 24
12	Gabinete PP Tipo 18
13	Gabinete PP Tipo 25
14	Gabinete PP Tipo 17
15	Gabinete RC
16	Cambiavía
17	Circuito de vía
18	Gabinete ATS - ERK

tbl_Equipment: tabla de equipos y más detalles (equipos = componentes padres)
ID_Equipment	EquipmentN1	EquipmentN2	EquipmentN3	FK_Equipment_Category	Subsystem	FK_Manufacturer	FK_EquipmentKind	FK_Stage	FK_Area
9	Vehículo	Tren	Tren 28	4	CBTC	1	1	1	
10	Vehículo	Tren	Tren 29	4	CBTC	1	1	1	
11	Gabinetes	ZC	ZC4	5	CBTC	1	3	1	4
12	Gabinetes	ZC	ZC2	5	CBTC	1	3	1	7
13	Gabinetes	ZC	ZC5	5	CBTC	1	3	1	4
14	Gabinetes	ZC	ZC3	5	CBTC	1	3	1	7
15	Gabinetes	Frontam	CUBÍCULO EQUIPADO DEL FRONTAM - PATIO	6	CBTC	1	7	1	4


tbl_Equipment_Activity_Area: tabla de equipo a mantener en un área en específico para un mantenimiento específico
ID_Equipment_Activity_Area	ID_Equipment	ID_Activity	ID_Area	Name_Activity_Equipment
1	1	1	1	MANTENIMIENTO PREVENTIVO DE SW DE ATS - PTSA
2	2	1	2	MANTENIMIENTO PREVENTIVO DE SW DE ATS - ECIN
3	3	2	3	Mantenimiento Simulador
4	4	23	4	Gabinete Inspección - CRK
5	4	24	4	Gabinete mantenimiento - CRK
6	5	3	5	Gabinete Inspección - ERK
7	5	4	5	Gabinete mantenimiento - ERK
8	6	5	6	MANTENIMIENTO PREVENTIVO DE EQUIPO A BORDO CC - Tren 14

tbl_Slot_image: imágenes que son usadas para mostrar ubicaciones de componentes
ID_SlotImage	FK_EquipmentKind	Name	Url	FK_SlotLocation	FK_Documentation	Page
1	1	Arquitectura Tren	https://hitachigroupeur.sharepoint.com/sites/L2-Mantenimientosealizacin/Shared%20Documents/Documentaci%C3%B3n%20del%20equipo/Reportes/Test-automatizacion/enviroments/PRD/Images/Tren/Arq_Tren.png		5	31
2	1	Arquitectura CC	https://hitachigroupeur.sharepoint.com/sites/L2-Mantenimientosealizacin/Shared%20Documents/Documentaci%C3%B3n%20del%20equipo/Reportes/Test-automatizacion/enviroments/PRD/Images/Tren/Arq_CC.png	7	5	37


tbl_Component_Type: tipo de componente (a nivel part number)
ID_ComponentType	PartNumber	Name	IsSerialized	INVENTORY_CODE_ETIQUETADO	FK_Subsystem	Description
8	3252.0100001	Thermostat	1	01A-025-SIG-IXL-0008	1	Mechanical thermostat 1 cont. NC
9	9001.0100055	MAR1040 L3 Switch 19" 16 X Combo Ports	1	01A-025-SIG-IXL-0009	1	MAR1040 L3 SWITCH 19" 16 X COMBO PORTS
10	A00B.0100009	FAN 48Vdc CONTROL SYSTEM RAL 7032                       	1	01A-025-SIG-IXL-0010	1	FAN 48Vdc CONTROL SYSTEM RAL 7032



tbl_Component: componentes a nivel serial number
ID_Component	FK_ComponentType	SerialNumber	Name	ManufactureDate	Model	Manufacturer	FK_Status	FK_CurrentLocation	LastMovementAt	FK_SlotLocation
1	134	107.1711	TIR 1 EQUIPED 600				1	4		10
2	135	111.1646	COMMAND RACK 1 1122				1	4		11
3	64	1099.1711	FAN				1	4		12


tbl_component_status: estatus del componente
ID_ComponentStatus	Name
1	OPERATIVO
2	INOPERATIVO
3	EN STOCK
4	PERDIDO
5	EN REPARACIÓN
6	EN TRANSPORTE

tbl_Slotlocation: ejemplo de árbol de jerarquía en componentes
ID_SlotLocation	NameSlotLocation	FK_TypeSlot	FK_FatherSlotLocation	Level	Is_LeafLevel	Seq	Path	IsInstallPointComponent	FK_EquipmentKind	IsInstallPointConsumable
1	M1	1		1	0	1	/M1	0	1	0
2	M2	1		1	0	6	/M2	0	1	0
3	R1	1		1	0	2	/R1	0	1	0
4	R2	1		1	0	5	/R2	0	1	0
5	S1	1		1	0	3	/S1	0	1	0
6	S2	1		1	0	4	/S2	0	1	0
7	CC	2	3	2	0	1	/R1/CC	0	1	0
8	Cubículo 1	3	7	3	0	1	/R1/CC/Cubículo 1	0	1	0
9	Cubículo 2	3	7	3	0	2	/R1/CC/Cubículo 2	0	1	0
10	TIR 1	4	8	4	0	1	/R1/CC/Cubículo 1/TIR 1	1	1	0
11	CDR 1	4	8	4	0	2	/R1/CC/Cubículo 1/CDR 1	1	1	0
12	FAN 3	4	8	4	0	3	/R1/CC/Cubículo 1/FAN 3	1	1	0
13	SCCR A	4	8	4	0	4	/R1/CC/Cubículo 1/SCCR A	1	1	0
14	FAN 1	4	8	4	0	5	/R1/CC/Cubículo 1/FAN 1	1	1	0
15	SCCR B	4	8	4	0	6	/R1/CC/Cubículo 1/SCCR B	1	1	0
16	FAN 2	4	8	4	0	7	/R1/CC/Cubículo 1/FAN 2	1	1	0
17	TIR 2	4	9	4	0	1	/R1/CC/Cubículo 2/TIR 2	1	1	0
18	CDR 2	4	9	4	0	2	/R1/CC/Cubículo 2/CDR 2	1	1	0
19	FAN 3	4	9	4	0	3	/R1/CC/Cubículo 2/FAN 3	1	1	0
20	SCCR B1	4	9	4	0	4	/R1/CC/Cubículo 2/SCCR B1	1	1	0
21	FAN 1	4	9	4	0	5	/R1/CC/Cubículo 2/FAN 1	1	1	0
22	SCCR B2	4	9	4	0	6	/R1/CC/Cubículo 2/SCCR B2	1	1	0
23	FAN2	4	9	4	0	7	/R1/CC/Cubículo 2/FAN2	1	1	0
24	CABA110 2601 11	5	10	5	1	1	/R1/CC/Cubículo 1/TIR 1/CABA110 2601 11	1	1	0
25	CABA110 2601 12	5	10	5	1	2	/R1/CC/Cubículo 1/TIR 1/CABA110 2601 12	1	1	0
26	CABA110 2601 13	5	10	5	1	3	/R1/CC/Cubículo 1/TIR 1/CABA110 2601 13	1	1	0
27	CABA110 2601 14	5	10	5	1	4	/R1/CC/Cubículo 1/TIR 1/CABA110 2601 14	1	1	0
28	CABA1/3	5	10	5	1	5	/R1/CC/Cubículo 1/TIR 1/CABA1/3	1	1	0
29	CABA2/4	5	10	5	1	6	/R1/CC/Cubículo 1/TIR 1/CABA2/4	1	1	0
30	SPARE CCVO-0	5	10	5	1	7	/R1/CC/Cubículo 1/TIR 1/SPARE CCVO-0	1	1	0



tbl_Type_Slot: tipo de slot (categoría en árbol)
ID_TypeSlot	Name
1	Coche
2	Equipo
3	Cubículo
4	Rack
5	Componente
6	Parte del gabinete

tbl_Type_Activity: tipo de actividad de mantenimiento
ID_TypeActivity	Name
1	Inspecciones / Levantamiento de Data
2	Limpieza
3	Cambio de Consumible
4	Cambio de Componente con uno externo
5	Reparación de Componente
6	Supervisión / Acompañamiento
7	Investigación / Pruebas / Constataciones
8	Generación de Informes / Reportes
9	Intercambio de Componentes
10	Transporte
11	Coordinación Orden de Trabajo
12	Otro


tbl_Consumable_Type: consumibles
ID_ConsumableType	Name	Description	Unit	IsActive
1	Filtro Gabinete	Filtro para las puertas de algún gabinete	UN	1
2	Limpia vidrios	Limpia vidrios para la limpieza de los gabinetes	LT	1
3	Paños industriales	Paños para la limpieza	UN	1


tbl_Movement_Type: tipo de movimiento
ID_MovementType	Name
1	INSTALADO
2	RETIRADO
3	INGRESO A ALMACÉN
4	RETIRO DE ALMACÉN
5	BOTADO
6	EN REPARACIÓN
7	INTERCAMBIO

tbl_Location: lugar en donde se hacen mantenimientos 
ID_Location	FK_LocationType	Name	FK_Equipment
1	1	Almacenamiento SPV	
2	1	Almacenamiento Mantto Hitachi	
3	2	Tren 14	6
4	2	Tren 26	7
5	2	Tren 27	8
6	2	Tren 28	9
7	2	Tren 29	10
8	3	Zone Controller 5	13
9	3	Zone Controller 4	11
10	3	Zone Controller 3	14
11	3	Zone Controller 2	12
12	3	Frontam Colectora	172


tbl_Location_Type: tipo de lugar
ID_LocationType	Name
1	Almacenamiento
2	Tren
3	Gabinete
4	Workstation



tbl_Conclusion_type: conclusión estandarizada (solo 1 mantenimiento tiene)
ID_Conclusion	FK_Activity	Conclusion_resume	Conclusion_description
1	21	Ajuste de señal CDBA	Durante el mantenimiento preventivo se verifico que los parámetros de la señal del circuito de vía en la herramienta CBDAC se encuentran desfasados del rango ideal, se realizo la modificacion de los parametros y al finalizar se comprueba el correcto funcionamiento del circuito de via.
2	21	Ajuste F1 y F2	Durante el mantenimiento preventivo se verifico que existe un desfasaje entre los valores de F1 y F2, se realizo reajuste de los parametros y al finalizar se comprueba el correcto funcionamiento del circuito de via.


tbl_Activity_Task: tareas o pasos del procedimiento de mantenimiento preventivo
ID_Activity_Task	Report_Code	Task	Comment	Page_Task	Num_Task
1	Informe A1	REVISIÓN DE LOS ARCHIVOS DE REGISTRO DEL SISTEMA		85	§9.1
2	Informe A1	VERIFICACIÓN DE LA HERRAMIENTA DE ESTADO DEL NODO		85	§9.2
3	Informe A1	VERIFICACIÓN DEL USO DE LA MEMORIA		85	§9.3
10	Informe A1S	REVISIÓN DE LOS ARCHIVOS DE REGISTRO DEL SISTEMA		85	§9.1
11	Informe A1S	VERIFICACIÓN DE LA HERRAMIENTA DE ESTADO DEL NODO		85	§9.2

tblPersonal_Activity: personal genérico necesario en cada actividad
Report_Code	Personal	N_persons	Hours	ID_Personal_Activity
Informe A1	Administrador del sistema	1	02:00	1
Informe A1S	Administrador del sistema	1	00:30	2
Informe A2	Técnico básico	2	00:30	3
Informe A3	Técnico básico	2	04:00	4
Informe C1	Técnico básico	5	06:00	5
Informe C2	Técnico básico	2	01:00	6


tbl_tools_activity: herramientas necesarias en cada mantenimiento
ID_Tool_Activity	Report_Code	Name_Serie	Q_tools	Hours
1	Informe A3	Kit de limpieza, aspiradora, limpia contactos, aire comprimido, cepillos.-	1	04:00
2	Informe A3	Papel toalla industrial X80.-	1	04:00
3	Informe C1	Kit de herramientas comunes (llaves, nivel de burbuja, octagonal#3, Torx, destornilladores).-	1	02:30
4	Informe C1	Kit de limpieza, aspiradora, limpia contactos, aire comprimido, cepillos, etc.-	1	02:30


tbl_test_task: pruebas en cada paso o tarea de mantenimiento
ID_Test_Task	FK_Activity	FK_Activity_Task	NameTest	TypeResult	TestNum_Task	Threshold_Min_Test	Threshold_Max_Test	Prefix	Unit
1	5	29	Inspección visual CC	str	1	-	-	-	-
2	5	30	Comprobación a tierra del CC 1	num	1	0	1	CC1	Ω
3	5	30	Comprobación a tierra del CC 2	num	2	0	1	CC2	Ω
4	5	31	Comprobación de ventiladores del CC	str	1	-	-	-	-


tbl_test_result: resultados posibles en las pruebas de cada tarea o paso
ID_Test_Result	FK_Test_Task	Result	Result_Default
1	1	Sin corrosión u óxido	1
2	1	Con corrosión u óxido	0
3	4	Ventiladores operativos	1
4	4	Ventiladores no operativos	0
5	5	Se limpiaron los racks	1
6	5	No se limpiaron los racks	0
7	6	Acelerómetro funcional	1
8	6	Acelerómetro con fallas	0
9	7	Apertura y cierre sin fallo	0
10	7	Falla en apertura y cierre	0


tbl_users: usuarios
ID_Worker	Name	Active	Path_Sign	Coordinator	Area	Email	Role
1	Carlos Valle	1	/Shared Documents/Documentación del equipo/Reportes/Test-automatizacion/signs/CarlosV_sign.png	0	2	Carlos.Valle@hitachirail.com	User
2	Diego Vera	1	/Shared Documents/Documentación del equipo/Reportes/Test-automatizacion/signs/DiegoV_sign.png	0	1	diego.vera@hitachirail.com	Administrator


tbl_tool: herramientas
ID_Tool	Model	Description	Serie	Brand	Name_short	Name_Serie
1	190-102	Osciloscopio digital de 2 canales 	69018104	Fluke	Osciloscopio	Osciloscopio-69018104
2	190-102	Osciloscopio digital de 2 canales 	61888101	Fluke	Osciloscopio	Osciloscopio-61888101
3	376 FC	Pinza amperimetrica inalambrica	67970789MV	Fluke	Pinza amperimétrica	Pinza amperimétrica-67970789MV
4	i3000s Flex-36	Sonda amperimetrica flexible para CA	43580022	Fluke	Sonda amperimétrica	Sonda amperimétrica-43580022


tbl_certification: certificación de herramientas
ID_Certification	Calibration_Company	Certification_Number	Calibration_Date	Certificate_Validity	Next_Calibration	FK_Tool	Active	Path
1	METRINDUST	MT-13335-2025	28/08/2025	365	28/08/2026	1	1	https://hitachigroupeur.sharepoint.com/sites/l2-mantenimientosealizacin/shared%20documents/documentaci%c3%b3n%20del%20equipo/reportes/test-automatizacion/documentation/herramientas/certificaciones/mt-13335-2025%20osciloscopio%20fluke%20190-102%20ot-12052-2025.pdf
2	METRINDUST	MT-13334-2025	28/08/2025	365	28/08/2026	2	1	https://hitachigroupeur.sharepoint.com/sites/l2-mantenimientosealizacin/shared%20documents/documentaci%c3%b3n%20del%20equipo/reportes/test-automatizacion/documentation/herramientas/certificaciones/mt-13334-2025%20osciloscopio%20fluke%20190-102%20ot-12052-2025.pdf



tbl_scheduled_activities: actividades programadas
ID_Scheduled_Activities	Report_Code	Month_Name	Month	Year	Item	Total_hours	Q_workers	FK_Equipment_Activity_Area	Date_Activity_Scheduled	Turn	Date_Activity_Done	Order_SAP	OT	Is_Done	FK_Maintenance_Storage
1	Informe C1	Febrero	2	2026	3.1.2.1	06:00	5	9	17/02/2026	Noche	17/02/2026	20030294	SPV-SEM08-2026-295	1	4084d78c-1f02-44ed-a615-9fac248dd3db
2	Informe C1	Enero	1	2026	3.1.4.1	06:00	5	11	07/01/2026	Noche	07/01/2026	-	SPV-SEM02-2026-183	1	036f612b-35ee-4748-b370-b4f72f78967a
3	Informe C1	Marzo	3	2026	3.1.5.1	06:00	5	12	19/03/2026	Noche	20/03/2026	20027392	SPV-SEM12-2026-229	1	ef5ca133-8f31-46e7-ba1f-dfb5884170c1


tbl_maintenance_storage: base de datos tipo datawarehouse
ID	Site	Proyect	Phase	System	ManualRef	Frequency	Code	InformCode	Worker	Date	DateEnd	Year	Month	Month_Name	Week	Day	Day_Name	HourInit	HourEnd	TimeMaintenanceMinutes	EquipmentN1	EquipmentN2	EquipmentN3	ActivityType	Activity	MaintenanceType	Subsystem	AreaN1	AreaN2	AreaN3	AreaN4	Conclusion	AditionalComments	RealCreatedAt_Hour	RealFinishedAt_Hour	UserCreation	EmailUserCreation	FK_Scheduled_Activities
9aa5c6d9-1742-4f7a-89ea-bb983e1be89a	Lima	METRO LÍNEA 2	Etapa 1A - Línea 2	Señalización	ML2-AST-GEN-G-000-GRAL-SSATS-GEN-MN-3500-0A	Revisión periódica diaria	SPV-SEM02-2026-	Informe A1	Joab Apaza;Fredy Navarrete Timoteo	31/12/2025	31/12/2025	2025	12	Diciembre	53	31	Miércoles	00:30	01:30	60	Servidores	Servidores	SYS101, SYS102, DBC101, COM101, COM102, CWS101, CWS102, CWS103, CWS104, CWS105, OVW101, OVW102	Inspecciones / Levantamiento de Data	MANTENIMIENTO PREVENTIVO DE SW DE ATS - ECIN	Preventivo	ATS	Estación	Colectora Industrial (PL22)	Área técnica	PCOE	Equipo Operativo		1/05/2026 21:21	1/05/2026 21:37	Joab Apaza	Joab.Apaza@hitachirail.com	1015



tbl_Workmaintenancecorrective: mantenimientos correctivos aperturados

ID_WorkMaintenanceCorrective	Date	Hour	Code	Name	TypeWork	Is_Finished
1	19/08/2025	15:37	110010514	E22 Falla de servidor Frontam	Correctivo	0
2	15/04/2026	07:42	110013642	PTSA TSAO Frontam sin Redundancia	Correctivo	0


tbl_reports: ubicación de los archivos generados
Id_Doc	FK_Maintenance_Storage	URL_File	Path_File	Format	Report_Type	Name_File
b35a9d40-b3e0-4001-9b74-713c63c7a131	0bbd52ac-6b9f-425b-8a29-ae4bd4abff67	https://hitachigroupeur.sharepoint.com/sites/L2-Mantenimientosealizacin/Shared%20Documents/Documentaci%C3%B3n%20del%20equipo/Reportes/Test-automatizacion/enviroments/PRD/Reports/Reporte_SPV-SEM03-2026-001_0bbd52ac-6b9f-425b-8a29-ae4bd4abff67.pdf	/Shared Documents/Documentación del equipo/Reportes/Test-automatizacion/enviroments/PRD/Reports/Reporte_SPV-SEM03-2026-001_0bbd52ac-6b9f-425b-8a29-ae4bd4abff67.pdf	pdf	Reporte de mantenimiento preventivo	Reporte_SPV-SEM03-2026-001_0bbd52ac-6b9f-425b-8a29-ae4bd4abff67.pdf



tbl_corrective_report_detail: detalle de cada actividad correctiva subida en reportes
ID_CorrectiveReport	FK_Maintenance_Storage	NumReport	1_Site	1_Proyect	1_Phase	1_System	1_AreaN1	1_AreaN2	1_AreaN3	1_FK_AreaN4	1_AreaN4	1_SubsystemSAP	1_FK_EquipmentReported	1_EquipmentCatReported	1_EquipmentN2Reported	1_EquipmentN3Reported	1_NameSAP	1_CodeSAP	1_DateCreationNotification	1_HourCreationNotification	1_Workers	2_FK_EquipmentReal	2_EquipmentN1Real	2_EquipmentN2Real	2_EquipmentN3Real	2_EquipmentCatReal	2_SubsystemID	2_SubsystemReal	2_IsCriticalElement	3_RecordedSymptomSAP	3_TechDescription	3_OperationalImpact	4_FailureType	5_ActivitiesDoneResume	7_FunctionalTest	7_ResultTest	7_ReleasedService	7_ResponsibleValidation	8_ResponseDate	8_ResponseHour	8_StartCorrectiveServiceDate	8_StartCorrectiveServiceHour	8_EndCorrectiveServiceDate	8_EndCorrectiveServiceHour	8_LiberationDate	8_LiberationHour	9_Conclusion	9_AditionalComments	RealStartDate	RealFinishedDate	UserCreationReport	EmailCreationReport	FK_WorkMaintenance	EndReportPoint
30e40b0a-e610-4726-9d35-fdd7f5d9383b	5d90343a-6d25-4249-8ce9-190acb166b29	1	Lima	METRO LÍNEA 2	Etapa 1A - Línea 2	Señalización	Estación	Colectora Industrial (PL22)	Área técnica	5	Sala 2.21	CBTC	172	Frontam - Gabinetes	Frontam	CUBÍCULO EQUIPADO DEL FRONTAM - COLECTORA	E22 Falla de servidor Frontam	110010514	19/08/2025	15:37	Diego Vera	172	Gabinetes	Frontam	CUBÍCULO EQUIPADO DEL FRONTAM - COLECTORA	Frontam - Gabinetes	3	CBTC	No	Se presenta falla de servidor Frontam en estación Colectora Industrial	"Personal de mantenimiento de señalización de Hitachi STS realizó 
mantenimiento correctivo de FRONTAM PCO-E. "	Degradación	Hardware	Inspecciones / Levantamiento de Data, Cambio de Componente, Otro, Investigación / Pruebas / Constataciones	Pruebas con movimiento de trenes desde CBTC desde PCON	Conforme	Sí	PCO	19/08/2025	15:50	19/08/2025	23:30	10/09/2025	03:00	10/09/2025	03:00	Operativo	"La configuración de los servidores de aplicación 01 y 02 del PCO-E se completó, se logró levantar 
la aplicación del FRONTAM en ambos servidores.  "	3/01/2026  16:30:00	3/01/2026  16:44:00	Diego Vera	Diego.Vera@hitachirail.com	1	0



tbl_Corrective_activities: actividades o pasos hechos en el mantenimiento correctivo
ID_CorrectiveActivities	FK_MaintenanceStorage	FK_TypeActivity	NameActivity	Description	DateIni	HourIni	DateEnd	HourEnd	Order
29717d68-4577-453b-a36c-83d073fff9e5	5d90343a-6d25-4249-8ce9-190acb166b29	1	Inspecciones / Levantamiento de Data	Daño en el equipo FRONTAM					1
ffdd79a0-3495-4d4a-9e7d-870e12f7db72	5d90343a-6d25-4249-8ce9-190acb166b29	4	Cambio de Componente con uno externo	Cambio del servidor de FRONTAM Application 1					2


tbk_workers_activities: trabajadores en un mantenimiento
ID_Workers_Activity	FK_Maintenance_Storage	FK_Worker
9aa5c6d9-1742-4f7a-89ea-bb983e1be89a_9	9aa5c6d9-1742-4f7a-89ea-bb983e1be89a	9
9aa5c6d9-1742-4f7a-89ea-bb983e1be89a_6	9aa5c6d9-1742-4f7a-89ea-bb983e1be89a	6

tbl_tools_activity: herramientas usadas en mantenimiento
ID_Tool_Activity	FK_Maintenance_Storage	FK_Tool	FK_Certification
9205590a-ff48-46dc-9271-0601a7135368	be177bcd-e598-417c-ac2a-5d6768f29e02	1	1
1d16a580-c588-497e-a312-f8506f8cfea5	be177bcd-e598-417c-ac2a-5d6768f29e02	6	6


task_activity: tarea o pasos realizados en los mantenimientos hechos
ID_Maintenance_Storage	Task	Check	Comment	ID_Tasks_activity
9aa5c6d9-1742-4f7a-89ea-bb983e1be89a	REVISIÓN DE LOS ARCHIVOS DE REGISTRO DEL SISTEMA	TRUE		9aa5c6d9-1742-4f7a-89ea-bb983e1be89a_1
9aa5c6d9-1742-4f7a-89ea-bb983e1be89a	VERIFICACIÓN DE LA HERRAMIENTA DE ESTADO DEL NODO	TRUE		9aa5c6d9-1742-4f7a-89ea-bb983e1be89a_2
9aa5c6d9-1742-4f7a-89ea-bb983e1be89a	VERIFICACIÓN DEL USO DE LA MEMORIA	TRUE		9aa5c6d9-1742-4f7a-89ea-bb983e1be89a_3

tbl_test_result_activity: resultado de las pruebas de cada paso
ID_Test_Result_Activity	FK_Tasks_activity	FK_Test_Task	Name_Test	Result	FK_Activity_Task
2cd90c18-ec28-49b2-81cf-250645b33d38	9aa5c6d9-1742-4f7a-89ea-bb983e1be89a_1	161	Archivos de registro del sistema	Ok	1
03925e14-edd0-42dc-bd5e-6b85463816c8	9aa5c6d9-1742-4f7a-89ea-bb983e1be89a_2	162	Herramienta de estado de nodo	Sistema funcionando con normalidad	2
2a459416-c618-4afe-8df4-f734b0116ac7	9aa5c6d9-1742-4f7a-89ea-bb983e1be89a_3	163	Uso de memoria	Memoria dentro de los niveles permitidos	3

images_activity: registro de imágenes que son subidos a los resportes
ID_Activity	Path_image	Path_URL	Name_image	Title	ID_Image
036f612b-35ee-4748-b370-b4f72f78967a	/Shared Documents/Documentación del equipo/Reportes/Test-automatizacion/enviroments/PRD/Reports/Images/SPV-SEM02-2026-183_036f612b-35ee-4748-b370-b4f72f78967a_1.jpeg	https://hitachigroupeur.sharepoint.com/sites/L2-Mantenimientosealizacin/Shared%20Documents/Documentación%20del%20equipo/Reportes/Test-automatizacion/enviroments/PRD/Reports/Images/SPV-SEM02-2026-183_036f612b-35ee-4748-b370-b4f72f78967a_1.jpeg	SPV-SEM02-2026-183_036f612b-35ee-4748-b370-b4f72f78967a_1.jpeg		1



tbl_calibration: tabla de calibraciones hechas
ID_Calibration	FK_Maintenance_Storage	FK_Report	CDV	Frequency	Date_Calibration	Location	Type_CDV	Number_CDV	Jumpers	Rail_Current	TCA9
2f05ce5b-78cf-4e66-a542-7bb6574495ff	47a6850e-25aa-473c-b1c8-ce6b812c3624	bb4b9227-6150-49ef-b161-2c7861862ce2	CBDAC 1018	12.5	14/01/2026	Patio Santa Anita	Transmisor	1	2-4-7-12-13	0	-
570a84e1-b093-4ffb-acf2-dd0bc7d6f678	47a6850e-25aa-473c-b1c8-ce6b812c3624	bb4b9227-6150-49ef-b161-2c7861862ce2	CBDAC 1018	12.5	14/01/2026	Patio Santa Anita	Receptor	1	2-3-4-8-9-13	240	E4-E7-E11-E16-E22-E23-E27


tbl_workordercomponent: tabla de movimiento de los componentes intercambiados en los mantenimientos correctivos
ID_WorkOrderComponent	FK_Maintenance	FK_CorrectiveActivities	FK_Equipment	EquipmentName	FK_Component	ComponentName	FK_MovementType	MovementTypeName	FK_StatusComponent	StatusComponentName	DateAction	Notes
190df42e-53ad-4a18-a28c-f8d6da2d37fb	5d90343a-6d25-4249-8ce9-190acb166b29	ffdd79a0-3495-4d4a-9e7d-870e12f7db72	172	CUBÍCULO EQUIPADO DEL FRONTAM - COLECTORA	757	Servidor Frontam | CZJ5470N75	2	RETIRADO	6	FALLADO	3/01/2026 16:44	
7724e0a6-3e72-4177-a551-9ec9d4413e73	5d90343a-6d25-4249-8ce9-190acb166b29	ffdd79a0-3495-4d4a-9e7d-870e12f7db72	172	CUBÍCULO EQUIPADO DEL FRONTAM - COLECTORA	760	Servidor Frontam | CZ3909PF9W	1	INSTALADO	1	FUNCIONANDO CORRECTAMENTE	3/01/2026 16:44	

tbl_componentmovement: tabla de movimiento de los componentes intercambiados en los mantenimientos correctivos
ID_ComponentMovement	FK_CorrectiveActivities	FK_Component	ComponentName_SN	FK_FromLocation	FromLocationName	FK_ToLocation	ToLocationName	FK_FromSlotLocation	FK_ToSlotLocation	FK_StatusComponent	StatusComponentName	FK_MovementType	MovementTypeName	MovedAt	FK_Maintenance	Notes	MovementKey
9d3ab32f-50b4-441e-83b7-dd0399efc42d	ffdd79a0-3495-4d4a-9e7d-870e12f7db72	757	Servidor Frontam | CZJ5470N75	12	Frontam Colectora	2	Almacenamiento Mantto Hitachi	182		2	INOPERATIVO	2	RETIRADO	3/01/2026 16:44	5d90343a-6d25-4249-8ce9-190acb166b29		1
a70e488c-0dd8-43ac-bbb0-7c201dab4367	ffdd79a0-3495-4d4a-9e7d-870e12f7db72	760	Servidor Frontam | CZ3909PF9W	1	Almacenamiento SPV	12	Frontam Colectora		182	1	OPERATIVO	1	INSTALADO	3/01/2026 16:44	5d90343a-6d25-4249-8ce9-190acb166b29		1


cabe recalcar que sobre las tablas que te muestro solo son para que te guíes de qué tipos de datos se usan, que valores se usan actualmente, pero no lo sigas al 100% debido a que las tablas actuales están muy mal hechas debido a que se fueron armando con el tiempo, inició con un proyecto pequeño pero se fue añadiendo más y más cosas tal que se agrandó bastante y no se tuvo la idea original por lo que está mal diseñado, hay varias columnas y tablas que ni uso y tablas que se repiten valores. Si tienes alguna pregunta puedes consultame y podré responderte para que puedas tener claridad.
