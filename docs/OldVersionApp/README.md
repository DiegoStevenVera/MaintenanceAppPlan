Carpeta para los documentos de la versión anterior de la aplicación. La versión anterior es la que fue construída con Power Apps.

* Database: Carpeta con los excels usados de base de datos. Cada excel tiene pestañas, cada una de estas pestañas es una tabla.
    * BD_Storage.xlsx: Acá se tiene los datos que generalmente se registran valores a través de la app. Son tablas que generalmente se van registrando valores a cada rato.
    * WBS_V2.xlsx: Acá se tiene más que nada tablas maestras que poseen tablas informativas que son usadas por la aplicación para crear valores en las tablas de BD_Storage.
* Formats: Son los formatos de reporte que son usados actualmente. Tras finalizar una actividad se genera un reporte preventivo o correctivo, estos reportes tienen el formato que están presentes aquí.
    * Report_Preventive_Template_V2.xlsx: Es el formato para los reportes preventivos.
    * Report_Corrective_Template_V3.xlsx: Es el formato para los reportes correctivos.
    * Calibration_Report.xlsx: Es el formato para los reportes de calibración, estos reportes son una excepción en los mantenimientos, ya que con cualquier mantenimiento preventivo solo se hace el reporte preventivo, pero con los mantenimientos preventivos de Circuito de vía se hace el reporte preventivo y también el reporte de calibración.
    * Examples: Carpeta con ejemplos de formato.
        * ML2-STS-FOR-040-ES MANT PREV IXL TIPO 24 PTSA PP 01-04-01_247.pdf: Reporte preventivo de un mantenimiento de puesto periférico.
        * ML2-STS-FOR-040-ES Circuito de vía mantenimiento - 2407_227.pdf: Reporte preventivo de un mantenimiento de circuito de vía.
        * 110015457_13-07-2026.pdf: Reporte correctivo de ejemplo.
        * Report_Calibration Circuito de vía mantenimiento - 2407.pdf: Reporte de calibración de ejemplo del mismo del cirucito de vía ejemplo 2407.
    * img: Carpeta de imágenes.
        * Hitachi-Logo.png: Logo de hitachi usado en los reportes.
* ReportsCode: Carpeta que contiene los office scripts que son usados para generar el reporte (tiene errores porque lo he sacado directamente y pegado en el archivo)
    * PreventiveScript: El script del reporte preventivo
    * CorrectiveScript: El script del reporte correctivo
    * CalibrationScript: El script del reporte de calibración