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

function diffHours(hourEnd: string, hourInit: string): string {
  const [hFin, mFin] = hourEnd.split(":").map(num => parseInt(num));
  const [hIni, mIni] = hourInit.split(":").map(num => parseInt(num));

  const dateBase = new Date(0, 0, 0, hIni, mIni);
  const dateEnd = new Date(0, 0, 0, hFin, mFin);

  let diff = dateEnd.getTime() - dateBase.getTime();

  // Si la diff es negativa, significa que pasó por medianoche
  if (diff < 0) {
    diff += 24 * 60 * 60 * 1000; // sumar 24 horas en milisegundos
  }

  const hours = Math.floor(diff / (1000 * 60 * 60));
  const mins = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

  // Formatear con ceros a la izquierda
  const hoursStr = hours.toString().padStart(2, "0");
  const minsStr = mins.toString().padStart(2, "0");

  return hoursStr + ':' + minsStr;
}

function splitArray(array: string[], size: number): string[][] {
  const result: string[][] = [];
  for (let i = 0; i < array.length; i += size) {
    result.push(array.slice(i, i + size));
  }
  return result;
}


async function main(workbook: ExcelScript.Workbook,
  varSite: string,
  varProyect: string,
  varPhase: string,
  varSystem: string,
  varCode: string,
  varWorker: string,
  varImagesSign: string,
  varDate: string,
  varHourInit: string,
  varHourEnd: string,
  varManualRef: string,
  varManualRefLink: string,
  varManualActivityPageIni: string,
  varManualActivityPageEnd: string,
  varFrequency: string,
  varEquipmentN1: string,
  varEquipmentN2: string,
  varEquipmentN3: string,
  varActivityType: string,
  varActivity: string,
  varSubsystem: string,
  varAreaN1: string,
  varAreaN2: string,
  varAreaN3: string,
  varAreaN4: string,
  varConclusion: string,
  varAditionalComments: string,
  varJsonString: string,
  varTestResultsJSON: string,
  varToolsString: string,
  varPersonalString: string,
  varImagesString: string) {
  const hojaReporte = workbook.getWorksheet("ATS001");

  hojaReporte.getRange("L3").setValue(varDate);
  hojaReporte.getRange("L4").setValue(varHourInit + " - " + varHourEnd);
  hojaReporte.getRange("I6").setValue(varAreaN2 + "/" + varAreaN4);
  hojaReporte.getRange("C6").setValue(varPhase);
  hojaReporte.getRange("D6").setValue(varSystem + " " + varSubsystem);

  // Para colocar el manual
  let page_range = '';

  // reconoce el rango de páginas
  if (varManualActivityPageIni == varManualActivityPageEnd) {
    page_range = '(Pag. ' + varManualActivityPageIni + ')'
  } else {
    page_range = '(Pag. ' + varManualActivityPageIni + '-' + varManualActivityPageEnd + ')'
  }

  // setea el nombre del manual
  let manual_cell = hojaReporte.getRange("C7");

  if (varManualRef == '-') {
    // si no hay manual se coloca solo '-'
    manual_cell.setValue(varManualRef);
  } else {
    // colocar con las páginas si hay manual
    const sampleHyperlink: ExcelScript.RangeHyperlink = {
      address: varManualRefLink + '#page=' + varManualActivityPageIni,
      screenTip: 'Manual de ' + varSubsystem,
      textToDisplay: varManualRef + ' ' + page_range
    }
    manual_cell.setHyperlink(sampleHyperlink);
    manual_cell.getFormat().getFont().setBold(true);
    manual_cell.getFormat().getFont().setUnderline(ExcelScript.RangeUnderlineStyle.none);
    manual_cell.getFormat().getFont().setColor("#000000");
  }

  hojaReporte.getRange("K7").setValue(varCode);
  hojaReporte.getRange("A9").setValue(varActivityType + " - " + varSubsystem);
  hojaReporte.getRange("D15").setValue(varActivity);
  hojaReporte.getRange("D16").setValue(varFrequency);

  let time_activity = diffHours(varHourEnd, varHourInit);
  const workers_list = varWorker.split(";").filter(p => p.trim() !== "");

  // Tasks
  let first_row_task = 18;

  const jsonTasks: {
    ID_Activity: string;
    Task: string;
    Check: boolean;
    Comment: string;
    Page_Task_Manual: string;
    Num_Task_Manual: string;
  }[] = JSON.parse(varJsonString);

  const jsonTasksResults: {
    Default_Result_Name: string;
    FK_Activity_Task: string;
    ID_Task_activity: string;
    ID_Test_Result_Activity: string;
    ID_Test_Task: string;
    NameTest: string;
    Prefix: string;
    Unit: string;
  }[] = JSON.parse(varTestResultsJSON);


  // Para tener el nuevo arreglo de resultados de los test agrupados
  const grouped: Record<string, string> = {};

  // Itera cada elemento del json para hacer el nuevo dictionary
  for (const item of jsonTasksResults) {
    const key = item.ID_Task_activity;
    var text = "";

    if (item.Prefix === "-") {
      text = item.Default_Result_Name;
    } else {
      text = item.Prefix + ": " + item.Default_Result_Name + item.Unit;
    }

    if (grouped[key]) {
      grouped[key] += " / " + text;
    } else {
      grouped[key] = text;
    }
  }

  // El dictionary se hace un array 
  const resultTestsGrouped = Object.values(grouped);
  var rowEndTask = first_row_task;

  for (let i = 0; i < jsonTasks.length; i++) {
    let task = jsonTasks[i];
    const targetRow = first_row_task + i;

    // Agregar una nueva fila
    if (i > 0) {
      hojaReporte.getRange(`${targetRow}:${targetRow}`).insert(ExcelScript.InsertShiftDirection.down);

      const srcFmt = hojaReporte.getRange(`A${targetRow - 1}:L${targetRow - 1}`);
      const dstFmt = hojaReporte.getRange(`A${targetRow}:L${targetRow}`);
      dstFmt.copyFrom(srcFmt, ExcelScript.RangeCopyType.formats, false);
    }

    // Para agregar el hyperlink del manual
    const taskHyperlink: ExcelScript.RangeHyperlink = {
      address: varManualRefLink + '#page=' + task.Page_Task_Manual,
      screenTip: 'Tarea de la actividad',
      textToDisplay: task.Num_Task_Manual
    }
    hojaReporte.getRange(`A${targetRow}`).setHyperlink(taskHyperlink);
    hojaReporte.getRange(`A${targetRow}`).getFormat().getFont().setBold(true);
    hojaReporte.getRange(`A${targetRow}`).getFormat().getFont().setUnderline(ExcelScript.RangeUnderlineStyle.none);
    hojaReporte.getRange(`A${targetRow}`).getFormat().getFont().setColor("#000000");
    hojaReporte.getRange(`B${targetRow}`).setValue(task.Task);
    hojaReporte.getRange(`F${targetRow}`).setValue(resultTestsGrouped[i]);
    hojaReporte.getRange(`J${targetRow}`).setValue(task.Comment);

    const h1 = calcularAlturaPorTexto(workbook, task.Task, `B${targetRow}:E${targetRow}`);
    const h2 = calcularAlturaPorTexto(workbook, resultTestsGrouped[i], `F${targetRow}:I${targetRow}`);
    const h3 = calcularAlturaPorTexto(workbook, task.Comment, `J${targetRow}:L${targetRow}`);

    const hRow = Math.max(h1, h2, h3);
    hojaReporte.getRange(`A${targetRow}`).getEntireRow().getFormat().setRowHeight(hRow);

    rowEndTask = targetRow;
  }

  // Tools
  const jsonTools: {
    ID_Tool: string;
    Name_Serie: string;
    Path_Certification: string;
  }[] = JSON.parse(varToolsString);

  var first_row = 10;

  for (let i = 0; i < jsonTools.length; i++) {
    const tool = jsonTools[i];
    const [name_tool, serie_tool] = tool.Name_Serie.split("-");

    const certification_link: ExcelScript.RangeHyperlink = {
      address: tool.Path_Certification,
      screenTip: 'Certificación de ' + name_tool,
      textToDisplay: tool.Path_Certification
    }
    hojaReporte.getCell(first_row + i, 10).setHyperlink(certification_link);
    hojaReporte.getCell(first_row + i, 10).getFormat().getFont().setColor("#000000");

    hojaReporte.getCell(first_row + i, 6).setValue(name_tool);
    hojaReporte.getCell(first_row + i, 10).setValue(serie_tool);
    hojaReporte.getCell(first_row + i, 11).setValue(time_activity);
  }

  // Personal Gen
  const jsonPersonal: {
    "@odata.etag": string;
    ItemInternalId: string;
    ID_Tools_Activity: string;
    Report_Code: string;
    Personal: string;
    N_persons: string;
    Hours: string;
  }[] = JSON.parse(varPersonalString);

  first_row = 10;

  for (let i = 0; i < jsonPersonal.length; i++) {
    const personal = jsonPersonal[i];
    hojaReporte.getCell(first_row + i, 0).setValue(personal.Personal);
    hojaReporte.getCell(first_row + i, 4).setValue(workers_list.length);
    hojaReporte.getCell(first_row + i, 5).setValue(time_activity);
  }

  // Conclusions
  let rowConclusion = rowEndTask + 2;
  let entire_conclusion = varConclusion + ": " + varAditionalComments;
  setCellWithAutoHeight(workbook, hojaReporte, `A${rowConclusion}:L${rowConclusion}`, entire_conclusion);

  // Workers
  let cell_first_worker = rowConclusion + 2;
  let date_sign = varDate;

  if (parseInt(varHourInit) < 24 && parseInt(varHourEnd) >= 0 && parseInt(varHourInit) > parseInt(varHourEnd)) {
    let [day, month, year] = varDate.split("/");
    let day_int = parseInt(day);
    let month_int = parseInt(month);
    let year_int = parseInt(year);

    let date_work = new Date(year_int, month_int - 1, day_int);
    date_work.setDate(date_work.getDate() + 1);

    const day_str = String(date_work.getDate()).padStart(2, "0");
    const month_str = String(date_work.getMonth() + 1).padStart(2, "0");
    const year_str = String(date_work.getFullYear());

    date_sign = day_str + "/" + month_str + "/" + year_str;
  }

  for (let i = 0; i < workers_list.length; i++) {
    let worker = workers_list[i];

    if (i >= 2) {
      hojaReporte.getRange("A" + ((cell_first_worker - 1) + 2 * i).toString()).copyFrom(`A${cell_first_worker + 1}:L${cell_first_worker + 2}`);
    }

    hojaReporte.getRange("A" + (cell_first_worker + 2 * i).toString()).setValue(worker);
    hojaReporte.getRange("K" + (cell_first_worker + 2 * i).toString()).setValue(date_sign);
  }

  // Signs
  let signs_list = varImagesSign.split("|").filter(p => p.trim() !== "");

  for (let i = 0; i < signs_list.length; i++) {
    let sign_image = hojaReporte.addImage(signs_list[i]);
    let sign_range = hojaReporte.getRange("J" + ((cell_first_worker - 1) + 2 * i).toString());

    sign_image.setTop(sign_range.getTop() + 5);
    sign_image.setLeft(sign_range.getLeft() + 5);
    sign_image.setHeight(20);
    sign_image.setWidth(40);

  }

  // Images
  let b64_images = varImagesString.split("|").filter(p => p.trim() !== "");

  if (b64_images.length != 0) {

    let blocks_b64_images = splitArray(b64_images, 6);

    for (let i = 0; i < blocks_b64_images.length; i++) {
      let hojaImagenes = workbook.addWorksheet(`Images ${i + 1}`);
      const cell_a40 = hojaImagenes.getRange("A3");
      let size_image = 210;

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
        const image = hojaImagenes.addImage(b64_image_i);

        const original_height = image.getHeight();
        const original_width = image.getWidth();
        const scale = Math.min(size_image / original_height, size_image / original_width)

        image.setTop(cell_a40.getTop() + (size_image + 10) * Math.floor(e / 2));
        image.setLeft(cell_a40.getLeft() + (size_image + 10) * (e % 2));
        image.setHeight(original_height * scale);
        image.setWidth(original_width * scale);
      }
    }
  }

}