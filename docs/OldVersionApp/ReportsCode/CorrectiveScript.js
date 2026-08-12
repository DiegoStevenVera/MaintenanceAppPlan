function obtenerAnchoEfectivoPts(rng: ExcelScript.Range): number {
  const ws = rng.getWorksheet();
  const cols = rng.getColumnCount();
  const anchoCol = (colIndex: number): number => {
    const temp = ws.getRangeByIndexes(rng.getRowIndex(), colIndex, 1, 1);
    return temp.getFormat().getColumnWidth();
  };

  if (cols <= 1) {
    return rng.getFormat().getColumnWidth();
  }

  let total = 0;
  const startCol = rng.getColumnIndex();
  for (let c = 0; c < cols; c++) {
    total += anchoCol(startCol + c);
  }
  return total;
}


function calcularAlturaPorTexto(workbook: ExcelScript.Workbook, texto: string, direccion: string): number {
  /**
   * 
   * PARAMS:
   * - texto: Variable que irá en la celda
   * - direccion: Dirección de la celda en formato (A3, B14, B7:H7, etc)
   */
  if (direccion == null || direccion.trim() === "") {
    throw new Error("La dirección no puede ser vacía.");
  }

  const ws = workbook.getActiveWorksheet();
  var rng = ws.getRange(direccion);

  const anchoPts = obtenerAnchoEfectivoPts(rng);

  const fmt = rng.getFormat();
  const font = fmt.getFont();
  const fontSize = Math.max(1, font.getSize() ?? 11); // pts
  // Línea aproximada ~ 1.2–1.3 × fontSize (depende de la fuente). Usamos 1.25 como término medio.
  const lineHeightPts = fontSize * 1.25;

  // Para fuentes tipo Calibri/Segoe UI: ancho medio ≈ 0.48 × fontSize (en puntos) por carácter.
  // Ajusta 0.48 si usas una fuente muy distinta (monoespaciada, etc).
  const puntosPorCaracter = 0.48 * fontSize;
  const charsPorLinea = Math.max(1, Math.floor(anchoPts / puntosPorCaracter));

  const textoPlano = (texto ?? "").toString();
  const parrafos = textoPlano.split(/\r?\n/);
  let totalLineas = 0;
  for (const p of parrafos) {
    const len = Math.max(1, p.length);
    totalLineas += Math.ceil(len / charsPorLinea);
  }

  const paddingPts = Math.max(2, Math.round(fontSize * 0.2));
  const alturaCalculada = Math.max(lineHeightPts, totalLineas * lineHeightPts + paddingPts);

  // 7) Opcional: no bajar nunca de la altura actual de la fila (por si ya es mayor)
  // const alturaActual = rng.getEntireRow().getFormat().getRowHeight();
  // return Math.max(alturaCalculada, alturaActual);

  return Math.ceil(alturaCalculada);
}


function setCellWithAutoHeight(
  workbook: ExcelScript.Workbook,
  hoja: ExcelScript.Worksheet,
  direccion: string,
  valor: string
) {
  /**
   * 
   * PARAMS
   * hoja: hoja actual en la que se escribe
   * direccion: Dirección de la celda en formato (A3, B14, B7:H7, etc)
   * valor: Variable que irá en la celda
   */
  let altura = calcularAlturaPorTexto(workbook, valor ?? "", direccion);

  if (typeof altura !== "number" || !Number.isFinite(altura)) {
    altura = 20;
  }

  altura = Math.ceil(altura);

  const MIN = 1;
  const MAX = 409.5;
  if (altura < MIN) altura = MIN;
  if (altura > MAX) altura = MAX;

  const rng = hoja.getRange(direccion);
  const fila = rng.getCell(0, 0).getEntireRow();

  rng.getFormat().setWrapText(true);
  fila.getFormat().setRowHeight(altura);

  rng.getCell(0, 0).setValue(valor ?? "");
}


function deleteRowsByRange(
  hoja: ExcelScript.Worksheet,
  rangeAddress: string
) {
  /**
   * 
   * PARAMS
   * hoja: hoja actual en la que se escribe
   * rangeAddress: Dirección de las celdas ("14:18")
   */
  hoja.getRange(rangeAddress).getEntireRow().delete(ExcelScript.DeleteShiftDirection.up);
}


function splitArray(array: {
  Photo: string;
  Title: string;
}[], size: number): {
  Photo: string;
  Title: string;
}[][] {
  const result: {
    Photo: string;
    Title: string;
  }[][] = [];
  for (let i = 0; i < array.length; i += size) {
    result.push(array.slice(i, i + size));
  }
  return result;
}


function main(workbook: ExcelScript.Workbook,
              varAreaN2: string,
              varAreaN3: string,
              varAreaN4: string,
              varEquipN2SAP: string,
              varEquipN3SAP: string,
              varCodeSAP: string,
              varNameSAP: string,
              varDateCreationSAP: string,
              varHourCreationSAP: string,
              varSubsystem: string,
              varEquipN2Real: string,
              varEquipN3Real: string,
              varCritElem: string,
              varSymptomRec: string,
              varTechDescription: string,
              varOperationalImpact: string,
              varFailureType: string,
              varActivitiesDoneStringJSON: string,
              varSparePartsStringJSON: string,
              varFunctionalTest: string,
              varResultTest: string,
              varReleasedService: string,
              varResponsibleValidation: string,
              varDateResponse: string,
              varHourResponse: string,
              varDateIni: string,
              varHourIni: string,
              varDateEnd: string,
              varHourEnd: string,
              varDateLiberationVal: string,
              varHourLiberationVal: string,
              varConclusion: string,
              varAditionalComments: string,
              varAuthorReport: string,
              varWorkersJSON: string,
              varDateCreationReport: string,
              varEndReportPoint: string,
              varImagesString: string,
              varNumReport: string
) {
  const hojaReporte = workbook.getWorksheet("Report");
  const endPointFlag = Number(varEndReportPoint);
  /** endPointFlag
  0: Completo
  1: Datos generales
  2: Activo señalización
  3: Descripción de falla(aviso SAP)
  4: Análisis de la falla
  5: Actividades correctivas ejecutadas
  6: Pruebas y validación
  */

  // 0. HEADER
  // FECHA
  hojaReporte.getRange("C5").setValue(`Fecha: ${varDateCreationReport}`);
  // N° REPORTE
  hojaReporte.getRange("J5").setValue(`N° REPORTE: ${varNumReport}/${varDateCreationReport.slice(-2)}`);

  // 1. DATOS GENERALES - TRAMO / ESTACIÓN
  setCellWithAutoHeight(workbook, hojaReporte, "F9:K9", `${varAreaN2} / ${varAreaN3} / ${varAreaN4}`);

  // 1. DATOS GENERALES - EQUIPO / ACTIVO
  setCellWithAutoHeight(workbook, hojaReporte, "F10:K10", `${varEquipN2SAP} / ${varEquipN3SAP}`);

  // 1. DATOS GENERALES - NOTIFICACIÓN / AVISO DE MANTENIMIENTO
  setCellWithAutoHeight(workbook, hojaReporte, "F11:K11", varNameSAP);

  // 1. DATOS GENERALES - ORDEN DE MANTENIMIENTO
  setCellWithAutoHeight(workbook, hojaReporte, "F12:K12", `'${varCodeSAP}`);

  // 1. DATOS GENERALES - FECHA Y HORA DE CREACIÓN DEL AVISO
  setCellWithAutoHeight(workbook, hojaReporte, "F13:K13", `'${varDateCreationSAP} ${varHourCreationSAP}`);

  // 2. ACTIVO DE SEÑALIZACIÓN
  hojaReporte.getRange("F17").setValue(varSubsystem);
  hojaReporte.getRange("F18").setValue(varEquipN2Real + "/" + varEquipN3Real);
  hojaReporte.getRange("F19").setValue(varCritElem);

  // 3. DESCRIPCIÓN DE LA FALLA
  setCellWithAutoHeight(workbook, hojaReporte, "F23:K23", varSymptomRec);
  setCellWithAutoHeight(workbook, hojaReporte, "F24:K24", varTechDescription);
  setCellWithAutoHeight(workbook, hojaReporte, "F25:K25", varOperationalImpact);

  // 4. ANÁLISIS DE LA FALLA
  hojaReporte.getRange("F29").setValue(varFailureType);

  // 5. ACTIVIDADES CORRECTIVAS EJECUTADAS
  var rowActivitiesDone = 34;
  var rowEndActivitiesDone = 34;

  const jsonActivitiesDone: {
    Item: Int16Array;
    Activity: string;
    ActivityTypeID: string;
    Description: string;
    DateIni: string;
    DateEnd: string;
    HourIni: string;
    HourEnd: string;
  }[] = JSON.parse(varActivitiesDoneStringJSON);


  const idsAEliminar = ["10", "11"];

  const jsonActivitiesFiltered = jsonActivitiesDone.filter(
    a => !idsAEliminar.includes(a.ActivityTypeID)
  );

  jsonActivitiesFiltered.forEach((activityItem, index) => {
    const targetRow = rowActivitiesDone + index;
    var descriptionActivityDate = `Fecha y hora inicio: ${activityItem.DateIni} ${activityItem.HourIni}\nFecha y hora fin: ${activityItem.DateEnd} ${activityItem.HourEnd}\n\n${activityItem.Description}`;

    if (index > 0) {
      hojaReporte.getRange(`${targetRow}:${targetRow}`).insert(ExcelScript.InsertShiftDirection.down);

      const srcFmt = hojaReporte.getRange(`B${targetRow - 1}:K${targetRow - 1}`);
      const dstFmt = hojaReporte.getRange(`B${targetRow}:K${targetRow}`);
      dstFmt.copyFrom(srcFmt, ExcelScript.RangeCopyType.formats, false);
    }

    const h1 = calcularAlturaPorTexto(workbook, activityItem.Activity, `C${targetRow}:E${targetRow}`)
    const h2 = calcularAlturaPorTexto(workbook, descriptionActivityDate, `F${targetRow}:K${targetRow}`)

    const hRow = Math.max(h1, h2);
    hojaReporte.getRange(`B${targetRow}`).getEntireRow().getFormat().setRowHeight(hRow);

    hojaReporte.getRange(`B${targetRow}`).setValue(index + 1);
    hojaReporte.getRange(`C${targetRow}`).setValue(activityItem.Activity);
    hojaReporte.getRange(`F${targetRow}`).setValue(descriptionActivityDate);

    rowEndActivitiesDone = targetRow;
  });

  // 6. REPUESTOS EMPLEADOS (Salida de materiales)
  var rowSpareParts = rowEndActivitiesDone + 5;
  var rowEndSpareParts = rowSpareParts;

  const jsonSpareParts: {
    MovementKey: string;
    ComponentName: string;
    ComponentSN: string;
    MovementType: number;
    MovementTypeName: string;
    FromLocationName: string;
    ToLocationName: string;
    EquipmentName: string;
  }[] = JSON.parse(varSparePartsStringJSON);

  jsonSpareParts.forEach((sparepartItem, index) => {
    const targetRow = rowSpareParts + index;
    var to_or_from_location = "";

    if (index > 0) {
      hojaReporte.getRange(`${targetRow}:${targetRow}`).insert(ExcelScript.InsertShiftDirection.down);

      const srcFmt = hojaReporte.getRange(`B${targetRow - 1}:K${targetRow - 1}`);
      const dstFmt = hojaReporte.getRange(`B${targetRow}:K${targetRow}`);
      dstFmt.copyFrom(srcFmt, ExcelScript.RangeCopyType.formats, false);
    }

    switch (sparepartItem.MovementType) {
      case 1:
        to_or_from_location = "Obtenido de: " + sparepartItem.FromLocationName;
        break;

      case 2:
        to_or_from_location = "Retirado hacia: " + sparepartItem.ToLocationName;
        break;

      case 7:
        to_or_from_location = "Intercambiados en: " + sparepartItem.EquipmentName;
        break;
    }


    const h1 = calcularAlturaPorTexto(workbook, sparepartItem.ComponentName, `C${targetRow}:D${targetRow}`)
    const h2 = calcularAlturaPorTexto(workbook, `'${sparepartItem.ComponentSN}`, `E${targetRow}:G${targetRow}`)
    const h3 = calcularAlturaPorTexto(workbook, sparepartItem.MovementTypeName, `H${targetRow}:I${targetRow}`)
    const h4 = calcularAlturaPorTexto(workbook, to_or_from_location, `J${targetRow}:K${targetRow}`)

    const hRow = Math.max(h1, h2, h3, h4);
    hojaReporte.getRange(`B${targetRow}`).getEntireRow().getFormat().setRowHeight(hRow);

    hojaReporte.getRange(`B${targetRow}`).setValue(index + 1);
    hojaReporte.getRange(`C${targetRow}`).setValue(sparepartItem.ComponentName);
    hojaReporte.getRange(`E${targetRow}`).setValue(`'${sparepartItem.ComponentSN}`);
    hojaReporte.getRange(`H${targetRow}`).setValue(sparepartItem.MovementTypeName);
    hojaReporte.getRange(`J${targetRow}`).setValue(to_or_from_location);

    rowEndSpareParts = targetRow;
  });

  // 7. PRUEBAS Y VALIDACIÓN OPERATIVA
  var rowTests = rowEndSpareParts + 4;
  var rowEndTests = rowEndSpareParts + 7;

  setCellWithAutoHeight(workbook, hojaReporte, `F${rowTests}:K${rowTests}`, varFunctionalTest);
  setCellWithAutoHeight(workbook, hojaReporte, `F${rowTests + 1}:K${rowTests + 1}`, varResultTest);
  setCellWithAutoHeight(workbook, hojaReporte, `F${rowTests + 2}:K${rowTests + 2}`, varReleasedService);
  setCellWithAutoHeight(workbook, hojaReporte, `F${rowEndTests}:K${rowEndTests}`, varResponsibleValidation);

  // 8. TIEMPOS DE MANTENIMIENTO
  var rowTime = rowEndTests + 4;
  var rowEndTime = rowEndTests + 8;

  hojaReporte.getRange(`G${rowTime}`).setValue(`'${varDateCreationSAP} ${varHourCreationSAP}`);
  hojaReporte.getRange(`G${rowTime + 1}`).setValue(`'${varDateResponse} ${varHourResponse}`);
  hojaReporte.getRange(`G${rowTime + 2}`).setValue(`'${varDateIni} ${varHourIni}`);
  hojaReporte.getRange(`G${rowTime + 3}`).setValue(`'${varDateEnd} ${varHourEnd}`);
  hojaReporte.getRange(`G${rowEndTime}`).setValue(`'${varDateLiberationVal} ${varHourLiberationVal}`);

  // 9. RESULTADOS FINALES
  var rowConclusion = rowEndTime + 4;
  var rowEndConclusion = rowEndTime + 6;

  hojaReporte.getRange(`F${rowConclusion}`).setValue(varConclusion);
  setCellWithAutoHeight(workbook, hojaReporte, `B${rowEndConclusion}:K${rowEndConclusion}`, varAditionalComments);

  // 10. APROBACIONES
  var rowWorkers = rowEndConclusion + 5;
  var rowEndWorkers = rowWorkers;

  // Workers
  const jsonWorkers: {
    ID_Worker: string;
    Name: string;
    Path_Sign: string;
    Email: string;
    ImageB64: string;
  }[] = JSON.parse(varWorkersJSON);

  jsonWorkers.forEach((workerItem, index) => {
    const targetRow = rowWorkers + index;

    if (index > 0) {
      hojaReporte.getRange(`${targetRow}:${targetRow}`).insert(ExcelScript.InsertShiftDirection.down);

      const srcFmt = hojaReporte.getRange(`B${targetRow - 1}:K${targetRow - 1}`);
      const dstFmt = hojaReporte.getRange(`B${targetRow}:K${targetRow}`);
      dstFmt.copyFrom(srcFmt, ExcelScript.RangeCopyType.formats, false);
    }

    let sign_image = hojaReporte.addImage(workerItem.ImageB64);
    let sign_range = hojaReporte.getRange(`J${targetRow}:K${targetRow}`);

    sign_image.setTop(sign_range.getTop() + 5);
    sign_image.setLeft(sign_range.getLeft() + 10);
    sign_image.setHeight(20);
    sign_image.setWidth(40);

    let charge = "Ingeniero de mantenimiento de Señalización";
    const h1 = calcularAlturaPorTexto(workbook, workerItem.Name, `B${targetRow}:E${targetRow}`);
    const h2 = calcularAlturaPorTexto(workbook, charge, `F${targetRow}:I${targetRow}`);

    const hRow = Math.max(h1, h2);
    hojaReporte.getRange(`B${targetRow}`).getEntireRow().getFormat().setRowHeight(hRow);

    hojaReporte.getRange(`B${targetRow}`).setValue(workerItem.Name);
    hojaReporte.getRange(`F${targetRow}`).setValue(charge);

    rowEndWorkers = targetRow;
  });

  var rowApprovals = rowEndWorkers + 2;

  hojaReporte.getRange(`F${rowApprovals}`).setValue(`${varAuthorReport}`);
  hojaReporte.getRange(`F${rowApprovals + 1}`).setValue(varDateCreationReport);

  const BLOCK_ROWS = {
    block1: `14:${rowEndConclusion}`,
    block2: `20:${rowEndConclusion}`,
    block3: `26:${rowEndConclusion}`,
    block4: `30:${rowEndConclusion}`,
    block5: `${rowEndSpareParts + 1}:${rowEndConclusion}`,
    block6: `${rowEndTests + 1}:${rowEndConclusion}`
  }

  switch(endPointFlag) {
    case 1: deleteRowsByRange(hojaReporte, BLOCK_ROWS.block1); break;
    case 2: deleteRowsByRange(hojaReporte, BLOCK_ROWS.block2); break;
    case 3: deleteRowsByRange(hojaReporte, BLOCK_ROWS.block3); break;
    case 4: deleteRowsByRange(hojaReporte, BLOCK_ROWS.block4); break;
    case 5: deleteRowsByRange(hojaReporte, BLOCK_ROWS.block5); break;
    case 6: deleteRowsByRange(hojaReporte, BLOCK_ROWS.block6); break;
  }

  // Images
  // let b64_images = varImagesString.split("|").filter(p => p.trim() !== "");

  const jsonImages: {
    Photo: string;
    Title: string;
  }[] = JSON.parse(varImagesString);

  const cells_title = ["A3", "F3", "A17", "F17", "A31", "F31"];

  if (jsonImages.length != 0) {

    let blocks_b64_images = splitArray(jsonImages, 6);

    for (let i = 0; i < blocks_b64_images.length; i++) {
      let hojaImagenes = workbook.addWorksheet(`Images ${i + 1}`);
      const cell_a40 = hojaImagenes.getRange("A4");
      let size_image = 191;

      const pageSetupReporte = hojaReporte.getPageLayout();
      const pageSetupImagenes = hojaImagenes.getPageLayout();

      // Igualar configuración
      pageSetupImagenes.setOrientation(pageSetupReporte.getOrientation());
      pageSetupImagenes.setPaperSize(pageSetupReporte.getPaperSize());
      pageSetupImagenes.setZoom(pageSetupReporte.getZoom());

      hojaImagenes.getRange('A1').setValue(`Registro Fotográfico ${i + 1}`);
      let b64_images_block_i = blocks_b64_images[i];

      for (let e = 0; e < b64_images_block_i.length; e++) {
        let b64_image_i = b64_images_block_i[e]
        const image = hojaImagenes.addImage(b64_image_i.Photo);

        const original_height = image.getHeight();
        const original_width = image.getWidth();
        const scale = Math.min(size_image / original_height, size_image / original_width)

        hojaImagenes.getRange(cells_title[e]).setValue(`${b64_image_i.Title}`);

        image.setTop(cell_a40.getTop() + (size_image + 20) * Math.floor(e / 2));
        image.setLeft(cell_a40.getLeft() + (size_image + 20) * (e % 2));
        image.setHeight(original_height * scale);
        image.setWidth(original_width * scale);
      }
    }
  }

}
