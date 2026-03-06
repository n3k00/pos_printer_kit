class PrinterUiStrings {
  const PrinterUiStrings({
    required this.connectedTitle,
    required this.connectingTitle,
    required this.searchingPrintersTitle,
    required this.selectPrinterTitle,
    required this.readyToSearchTitle,
    required this.connectedSubtitle,
    required this.connectingSubtitle,
    required this.searchingSubtitle,
    required this.selectPrinterSubtitle,
    required this.readyToSearchSubtitle,
    required this.printersFoundLabel,
    required this.noBlePrinterFoundLabel,
    required this.startSearchingButton,
    required this.stopSearchingButton,
    required this.disconnectButton,
    required this.doneButton,
    required this.connectingButton,
  });

  static const PrinterUiStrings en = PrinterUiStrings(
    connectedTitle: 'CONNECTED',
    connectingTitle: 'CONNECTING',
    searchingPrintersTitle: 'SEARCHING PRINTERS',
    selectPrinterTitle: 'SELECT PRINTER',
    readyToSearchTitle: 'READY TO SEARCH',
    connectedSubtitle: 'Printer is ready to print.',
    connectingSubtitle: 'Connecting to printer. Please wait.',
    searchingSubtitle: 'Searching nearby Bluetooth printers...',
    selectPrinterSubtitle: 'Tap a printer to connect.',
    readyToSearchSubtitle: 'Tap Start Searching to find printers.',
    printersFoundLabel: 'Printers found:',
    noBlePrinterFoundLabel: 'No Bluetooth printer found',
    startSearchingButton: 'Start Searching',
    stopSearchingButton: 'Stop Searching',
    disconnectButton: 'Disconnect',
    doneButton: 'Done',
    connectingButton: 'Connecting...',
  );

  static const PrinterUiStrings my = PrinterUiStrings(
    connectedTitle: '????????????',
    connectingTitle: '?????????????',
    searchingPrintersTitle: '?????????? ???????????',
    selectPrinterTitle: '?????? ??????',
    readyToSearchTitle: '????????? ?????',
    connectedSubtitle: '?????? ??????????????????',
    connectingSubtitle: '?????????? ?????????????? ???????????',
    searchingSubtitle: '???????? Bluetooth ?????????? ???????????...',
    selectPrinterSubtitle: '??????????? ?????????????? ????????',
    readyToSearchSubtitle: '???????????? ????????????? ???????????',
    printersFoundLabel: '?????????? ??????????:',
    noBlePrinterFoundLabel: 'Bluetooth ?????? ???????',
    startSearchingButton: '?????????????',
    stopSearchingButton: '????????? ??????',
    disconnectButton: '??????????? ????????',
    doneButton: '?????????',
    connectingButton: '?????????????...',
  );

  final String connectedTitle;
  final String connectingTitle;
  final String searchingPrintersTitle;
  final String selectPrinterTitle;
  final String readyToSearchTitle;
  final String connectedSubtitle;
  final String connectingSubtitle;
  final String searchingSubtitle;
  final String selectPrinterSubtitle;
  final String readyToSearchSubtitle;
  final String printersFoundLabel;
  final String noBlePrinterFoundLabel;
  final String startSearchingButton;
  final String stopSearchingButton;
  final String disconnectButton;
  final String doneButton;
  final String connectingButton;

  PrinterUiStrings copyWith({
    String? connectedTitle,
    String? connectingTitle,
    String? searchingPrintersTitle,
    String? selectPrinterTitle,
    String? readyToSearchTitle,
    String? connectedSubtitle,
    String? connectingSubtitle,
    String? searchingSubtitle,
    String? selectPrinterSubtitle,
    String? readyToSearchSubtitle,
    String? printersFoundLabel,
    String? noBlePrinterFoundLabel,
    String? startSearchingButton,
    String? stopSearchingButton,
    String? disconnectButton,
    String? doneButton,
    String? connectingButton,
  }) {
    return PrinterUiStrings(
      connectedTitle: connectedTitle ?? this.connectedTitle,
      connectingTitle: connectingTitle ?? this.connectingTitle,
      searchingPrintersTitle:
          searchingPrintersTitle ?? this.searchingPrintersTitle,
      selectPrinterTitle: selectPrinterTitle ?? this.selectPrinterTitle,
      readyToSearchTitle: readyToSearchTitle ?? this.readyToSearchTitle,
      connectedSubtitle: connectedSubtitle ?? this.connectedSubtitle,
      connectingSubtitle: connectingSubtitle ?? this.connectingSubtitle,
      searchingSubtitle: searchingSubtitle ?? this.searchingSubtitle,
      selectPrinterSubtitle:
          selectPrinterSubtitle ?? this.selectPrinterSubtitle,
      readyToSearchSubtitle:
          readyToSearchSubtitle ?? this.readyToSearchSubtitle,
      printersFoundLabel: printersFoundLabel ?? this.printersFoundLabel,
      noBlePrinterFoundLabel:
          noBlePrinterFoundLabel ?? this.noBlePrinterFoundLabel,
      startSearchingButton: startSearchingButton ?? this.startSearchingButton,
      stopSearchingButton: stopSearchingButton ?? this.stopSearchingButton,
      disconnectButton: disconnectButton ?? this.disconnectButton,
      doneButton: doneButton ?? this.doneButton,
      connectingButton: connectingButton ?? this.connectingButton,
    );
  }

  static PrinterUiStrings forLanguageCode(String languageCode) {
    return languageCode.toLowerCase() == 'my' ? my : en;
  }
}

class PrinterUiTextOverrides {
  const PrinterUiTextOverrides({
    this.connectedTitle,
    this.connectingTitle,
    this.searchingPrintersTitle,
    this.selectPrinterTitle,
    this.readyToSearchTitle,
    this.connectedSubtitle,
    this.connectingSubtitle,
    this.searchingSubtitle,
    this.selectPrinterSubtitle,
    this.readyToSearchSubtitle,
    this.printersFoundLabel,
    this.noBlePrinterFoundLabel,
    this.startSearchingButton,
    this.stopSearchingButton,
    this.disconnectButton,
    this.doneButton,
    this.connectingButton,
  });

  final String? connectedTitle;
  final String? connectingTitle;
  final String? searchingPrintersTitle;
  final String? selectPrinterTitle;
  final String? readyToSearchTitle;
  final String? connectedSubtitle;
  final String? connectingSubtitle;
  final String? searchingSubtitle;
  final String? selectPrinterSubtitle;
  final String? readyToSearchSubtitle;
  final String? printersFoundLabel;
  final String? noBlePrinterFoundLabel;
  final String? startSearchingButton;
  final String? stopSearchingButton;
  final String? disconnectButton;
  final String? doneButton;
  final String? connectingButton;

  PrinterUiStrings applyTo(PrinterUiStrings base) {
    return base.copyWith(
      connectedTitle: connectedTitle,
      connectingTitle: connectingTitle,
      searchingPrintersTitle: searchingPrintersTitle,
      selectPrinterTitle: selectPrinterTitle,
      readyToSearchTitle: readyToSearchTitle,
      connectedSubtitle: connectedSubtitle,
      connectingSubtitle: connectingSubtitle,
      searchingSubtitle: searchingSubtitle,
      selectPrinterSubtitle: selectPrinterSubtitle,
      readyToSearchSubtitle: readyToSearchSubtitle,
      printersFoundLabel: printersFoundLabel,
      noBlePrinterFoundLabel: noBlePrinterFoundLabel,
      startSearchingButton: startSearchingButton,
      stopSearchingButton: stopSearchingButton,
      disconnectButton: disconnectButton,
      doneButton: doneButton,
      connectingButton: connectingButton,
    );
  }
}
