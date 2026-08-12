
function main(workbook: ExcelScript.Workbook,
            cdv: string,
            location: string,
            date_calibration: string,
            freq: string,
            jumper_transmisor: string,
            workers: string,
            receiver_json_string: string
            ) {
    let selectedSheet = workbook.getActiveWorksheet();
    const workers_list = workers.split(";").filter(p => p.trim() !== "");

    selectedSheet.getRange("A2").setValue("MANTENIMIENTO PREVENTIVO DE CIRCUITO DE VIA - " + location);
    selectedSheet.getRange("B3").setValue(cdv);
    selectedSheet.getRange("B4").setValue(freq + " KHz");
    selectedSheet.getRange("B5").setValue(date_calibration);
    selectedSheet.getRange("B11").setValue(jumper_transmisor);
    selectedSheet.getRange("E23").setValue("Fecha: " + date_calibration);
    selectedSheet.getRange("E25").setValue("Fecha: " + date_calibration);

    const cell_first_worker = 25;

    for (let i = 0; i < workers_list.length; i++) {
        let worker = workers_list[i];

        if (i >= 1) {
            selectedSheet.getRange("A" + ((cell_first_worker - 1) + 2 * i).toString()).copyFrom("A24:E25");
        }

        selectedSheet.getRange("A" + (cell_first_worker + 2 * i).toString()).setValue(worker);
        // selectedSheet.getRange("K" + (cell_first_worker + 2 * i).toString()).setValue(date_sign);
    }

    const json_receiver: {
            ID: string;
            JumpR: string;
            RailC: boolean;
            TCAR: string;
    }[] = JSON.parse(receiver_json_string);
        
    for (let i = 0; i < json_receiver.length; i++) {
      let receiver_n = json_receiver[i];
      // Jumpers del receptor N
        selectedSheet.getRange("A" + (7 + i).toString()).setValue("MABF RX" + receiver_n.ID);
        selectedSheet.getRange("B" + (7 + i).toString()).setValue(receiver_n.JumpR);
      // Corriente del receptor N
        selectedSheet.getRange("A" + (13 + i).toString()).setValue("Corriente Riel (En RX" + receiver_n.ID + ")");
        selectedSheet.getRange("B" + (13 + i).toString()).setValue(receiver_n.RailC + " mA");
      // Jumpers TCA9 RX
        selectedSheet.getRange("A" + (17 + i).toString()).setValue("TCA9 RX" + receiver_n.ID);
        selectedSheet.getRange("B" + (17 + i).toString()).setValue(receiver_n.TCAR);
    }



}
