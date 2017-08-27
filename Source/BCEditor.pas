﻿unit BCEditor;

interface {********************************************************************}

uses
  Windows, Messages, ActiveX, GDIPAPI, GDIPObj,
  Classes, SysUtils, UITypes, StrUtils, Generics.Collections, SyncObjs,
  Forms, StdActns, Controls, Graphics, StdCtrls, Dialogs, Consts,
  Menus,
  BCEditor.Commands, BCEditor.CompletionProposal, BCEditor.Consts,
  BCEditor.GotoLine, BCEditor.Highlighter, BCEditor.Lines, BCEditor.Properties,
  BCEditor.Types;

type
  TCustomBCEditor = class(TCustomControl, IDropSource, IDropTarget)
  private type
    TPaintHelper = class;

    TBCEditorColors = class(BCEditor.Properties.TBCEditorColors);
    TBCEditorCompletionProposal = class(BCEditor.Properties.TBCEditorCompletionProposal);
    TBCEditorCompletionProposalPopup = class(BCEditor.CompletionProposal.TBCEditorCompletionProposalPopup);
    TBCEditorHighlighter = class(BCEditor.Highlighter.TBCEditorHighlighter);
    TBCEditorLeftMargin = class(BCEditor.Properties.TBCEditorLeftMargin);
    TBCEditorLines = class(BCEditor.Lines.TBCEditorLines);
    TBCEditorTabs = class(BCEditor.Properties.TBCEditorTabs);


    TDropData = class(TInterfacedObject, IDataObject, IEnumFORMATETC)
    private
      FEditor: TCustomBCEditor;
      FEnumFormatEtcIndex: Integer;
    protected
      function Clone(out Enum: IEnumFormatEtc): HResult; stdcall;
      function DAdvise(const formatetc: TFormatEtc; advf: Longint;
        const advSink: IAdviseSink; out dwConnection: Longint): HResult; stdcall;
      function DUnadvise(dwConnection: Longint): HResult; stdcall;
      function EnumDAdvise(out enumAdvise: IEnumStatData): HResult; stdcall;
      function EnumFormatEtc(dwDirection: Longint; out enumFormatEtc:
        IEnumFormatEtc): HResult; stdcall;
      function GetCanonicalFormatEtc(const formatetc: TFormatEtc;
        out formatetcOut: TFormatEtc): HResult; stdcall;
      function GetData(const formatetcIn: TFormatEtc; out medium: TStgMedium):
        HResult; stdcall;
      function GetDataHere(const formatetc: TFormatEtc; out medium: TStgMedium):
        HResult; stdcall;
      function Next(celt: Longint; out elt; pceltFetched: PLongint): HResult; stdcall;
      function QueryGetData(const formatetc: TFormatEtc): HResult; stdcall;
      function Reset(): HResult; stdcall;
      function SetData(const formatetc: TFormatEtc; var medium: TStgMedium;
        fRelease: BOOL): HResult; stdcall;
      function Skip(celt: Longint): HResult; stdcall;
    public
      constructor Create(const AEditor: TCustomBCEditor);
    end;

    TClientJob = (cjTokenWidth, cjPaint, cjPaintOverlays,
      cjMouseDown, cjMouseDblClk, cjMouseTrplClk, cjMouseMove, cjMouseUp,
      cjHint, cjScrolling);

    TMouseCapture = (mcNone, mcSyncEditButton, mcMarks,
      mcLineState, mcCodeFolding, mcText, mcScrolling);

    TState = set of (esCaretInvalid, esCodeFoldingInvalid, esDoubleBufferInvalid,
      esMatchedPairInvalid, esRowsInvalid, esScrollBarsInvalid, esSyncEditInvalid,
      esSyncEditOverlaysInvalid,
      esCaretChanged, esFontChanged, esHighlighterChanged, esSelChanged,
      esSizeChanged, esSysFontChanged, esTextChanged,
      esDragging, esPainting, esScrolling, ecProcessingCommand,
      esTextUpdated,
      esHighlightSearchAllAreas,
      esKeyHandled, esWaitForDrag, esMouseDblClk, esCenterCaret);

    TBuildRowsThread = class(TThread)
    private
      FDC: HDC;
      FEditor: TCustomBCEditor;
      FPaintHelper: TCustomBCEditor.TPaintHelper;
      function Terminated(): Boolean;
    protected
      procedure Execute(); override;
    public
      constructor Create(const AEditor: TCustomBCEditor);
      destructor Destroy(); override;
    end;

    TMetrics = record
      ClientRect: TRect;
      CodeFoldingRect: TRect;
      LineHeight: Integer;
      MarksPanelRect: TRect;
      LeftMarginBorderRect: TRect;
      LineNumbersRect: TRect;
      LineStateRect: TRect;
      TextRect: TRect;
    end;

    TOverlay = record
      Area: TBCEditorLinesArea;
      Style: (osRect, osUnderline, osWaveLine);
    end;

    TOverlays = class(TList<TOverlay>)
    private
      FEditor: TCustomBCEditor;
    public
      function Add(const AValue: TOverlay): Integer;
      constructor Create(const AEditor: TCustomBCEditor);
    end;

    TPaintHelper = class(TObject)
    type

      TObjectFont = packed record
        Handle: HFont;
        Style: TFontStyles;
      end;

      TObjectFonts = class(TList<TObjectFont>)
      strict private
        FFont: TFont;
        procedure SetFont(const AValue: TFont);
      public
        function Add(const AStyle: TFontStyles): Integer;
        procedure Clear();
        constructor Create();
        destructor Destroy(); override;
        property Font: TFont read FFont write SetFont;
      end;

    strict private
      FBackgroundColor: TColor;
      FBrush: TBrush;
      FForegroundColor: TColor;
      FHandle: HDC;
      FHandles: TStack<HDC>;
      FObjectFonts: TObjectFonts;
      FSavedDCs: TStack<Integer>;
      FStyle: TFontStyles;
      procedure SetBackgroundColor(const AValue: TColor);
      procedure SetFont(const AValue: TFont);
      procedure SetForegroundColor(const AValue: TColor);
      procedure SetStyle(const AValue: TFontStyles);
    public
      procedure BeginDraw(const AHandle: HDC);
      constructor Create(const AFont: TFont);
      destructor Destroy(); override;
      procedure EndDraw();
      function ExtTextOut(X, Y: Integer; Options: Longint;
        Rect: TRect; Str: LPCWSTR; Count: Longint; Dx: PInteger): BOOL; {$IFNDEF Debug} inline; {$ENDIF}
      function FillRect(const ARect: TRect): BOOL; {$IFNDEF Debug} inline; {$ENDIF}
      function FrameRect(const ARect: TRect; AColor: TColor): Integer; {$IFNDEF Debug} inline; {$ENDIF}
      function TextHeight(const AText: PChar; const ALength: Integer): Integer;
      function TextWidth(const AText: PChar; const ALength: Integer): Integer;
      property BackgroundColor: TColor read FBackgroundColor write SetBackgroundColor;
      property Handle: HDC read FHandle;
      property ForegroundColor: TColor read FForegroundColor write SetForegroundColor;
      property Font: TFont write SetFont;
      property Style: TFontStyles read FStyle write SetStyle;
    end;

    PPaintVar = ^TPaintVar;
    TPaintVar = record
    type
      TPart = record
      type
        TPartType = (ptNormal, ptSyncEdit, ptMatchingPair, ptSelection,
          ptSearchResult);
      public
        BeginPosition: TBCEditorLinesPosition;
        EndPosition: TBCEditorLinesPosition;
        PartType: TPartType;
      end;
    public
      Graphics: TGPGraphics;
      LeftMarginBorderBrush: TGPBrush;
      LineBackgroundColor: TColor;
      LineForegroundColor: TColor;
      OverlayIndex: Integer;
      OverlayRectBrush: TGPBrush;
      OverlayUnderlineBrush: TGPBrush;
      Parts: TList<TPart>;
      PreviousBackgroundColor: TColor;
      PreviousFontStyles: TFontStyles;
      PreviousUCC: Boolean;
      SearchResultIndex: Integer;
      SelArea: TBCEditorLinesArea;
      UCCBrush: TGPBrush;
    end;

    TRow = record
    type
      TFlags = set of (rfFirstRowOfLine, rfLastRowOfLine, rfHasTabs);
      TPart = record
        BeginRange: Pointer;
        Char: Integer;
        Column: Integer;
        Left: Integer;
      end;
      TParts = array of TPart;
    public
      BeginRange: Pointer;
      Char: Integer;
      Columns: Integer;
      Flags: TFlags;
      Length: Integer;
      Line: Integer;
      Parts: TParts;
      Width: Integer;
    end;

    TRows = class(TList<TRow>)
    type
      TState = set of (rsBuilding);
    private
      FCaretPosition: TBCEditorRowsPosition;
      FCriticalSection: TCriticalSection;
      FEditor: TCustomBCEditor;
      FMaxColumns: Integer;
      FMaxColumnsRow: Integer;
      FMaxWidth: Integer;
      FMaxWidthRow: Integer;
      FState: TRows.TState;
      function GetCaretPosition(): TBCEditorRowsPosition;
      function GetCount(): Integer;
      function GetBORPosition(ARow: Integer): TBCEditorLinesPosition;
      function GetEORPosition(ARow: Integer): TBCEditorLinesPosition;
      function GetFmtText(): string;
      function GetItem(AIndex: Integer): TRow;
      function GetMaxColumns(): Integer;
      function GetMaxWidth(): Integer;
      function GetRowArea(ARow: Integer): TBCEditorLinesArea;
      function GetText(ARow: Integer): string;
    public
      procedure Add(const AFlags: TRow.TFlags; const ALine: Integer;
        const AChar, ALength, AColumns, AWidth: Integer;
        const ABeginRange: Pointer; const AParts: TRow.TParts); {$IFNDEF Debug} inline; {$ENDIF}
      procedure BeginBuild();
      procedure Clear();
      constructor Create(const AEditor: TCustomBCEditor);
      procedure Delete(ARow: Integer);
      destructor Destroy(); override;
      procedure EndBuild();
      procedure Insert(ARow: Integer;
        const AFlags: TRow.TFlags; const ALine: Integer;
        const AChar, ALength, AColumns, AWidth: Integer;
        const ABeginRange: Pointer; const AParts: TRow.TParts);
      property CaretPosition: TBCEditorRowsPosition read GetCaretPosition;
      property Count: Integer read GetCount;
      property BORPosition[Row: Integer]: TBCEditorLinesPosition read GetBORPosition;
      property EORPosition[Row: Integer]: TBCEditorLinesPosition read GetEORPosition;
      property FmtText: string read GetFmtText;
      property Items[Index: Integer]: TRow read GetItem;
      property MaxColumns: Integer read GetMaxColumns;
      property MaxWidth: Integer read GetMaxWidth;
      property RowArea[Row: Integer]: TBCEditorLinesArea read GetRowArea;
      property State: TRows.TState read FState;
      property Text[Row: Integer]: string read GetText; default;
    end;

    TRowsWanted = record
      CenterCaret: Boolean;
      Position: TBCEditorLinesPosition;
      Row: Integer;
      Select: Boolean;
      What: (rwNothing, rwPaintText, rwScrollToPosition, rwDown, rwEOF);
    end;

  private const
    DefaultFontName = 'Courier New';
    DefaultOptions = [eoDropFiles, eoAutoIndent, eoHighlightAllFoundTexts,
      eoHighlightActiveLine, eoHighlightMatchingPairs, eoMiddleClickScrolling];
    DefaultSelectionOptions = [soHighlightWholeLine, soTripleClickLineSelect];
    DefaultSyncEditOptions = [seoShowButton, seoCaseSensitive];
    DefaultUndoOptions = [uoGroupUndo];
    UM_FIND_ALLAREAS = WM_USER + 1;
    UM_FIND_WRAPAROUND = WM_USER + 2;
    UM_FREE_COMPLETIONPROPOSALPOPUP = WM_USER + 3;
    UM_ROWSAVAILABLE = WM_USER + 4;
    UM_UPDATE_SCROLLBARS = WM_USER + 5;
  private
    FAfterProcessCommand: TBCEditorAfterProcessCommandEvent;
    FAllCodeFoldingRanges: TBCEditorCodeFoldingAllRanges;
    FBeforeProcessCommand: TBCEditorBeforeProcessCommandEvent;
    FBookmarkBitmaps: array[0 .. BCEDITOR_BOOKMARKS - 1] of TGPCachedBitmap;
    FBoldDotSignWidth: Integer;
    FBorderStyle: TBorderStyle;
    FBuildRowsCriticalSection: TCriticalSection;
    FBuildRowsThread: TBuildRowsThread;
    FCaretPos: TPoint; // Caret position in pixel - NOT related to CaretPos!
    FCaretVisible: Boolean;
    FCaretWidth: Integer;
    FCodeFoldingCollapsedBitmap: TGPCachedBitmap;
    FCodeFoldingCollapsedMarkWidth: Integer;
    FCodeFoldingEndLineBitmap: TGPCachedBitmap;
    FCodeFoldingExpandedBitmap: TGPCachedBitmap;
    FCodeFoldingLineBitmap: TGPCachedBitmap;
    FCodeFoldingNoneBitmap: TGPCachedBitmap;
    FCodeFoldingWidth: Integer;
    FColors: TBCEditorColors;
    FCompletionProposal: TBCEditorCompletionProposal;
    FCompletionProposalPopup: TBCEditorCompletionProposalPopup;
    FDefaultFontSize: Integer;
    FDoubleClickTime: Cardinal;
    FDoubleBufferBitmap: TBitmap;
    FDoubleBufferOverlayBitmap: TBitmap;
    FDoubleBufferUpdateRect: TRect;
    FFontPitchFixed: Boolean;
    FFormWnd: HWND;
    FHideSelectionBeforeSearch: Boolean;
    FHideScrollBars: Boolean;
    FHighlighter: TBCEditorHighlighter;
    FCursorPoint: TPoint;
    FDlgCtrlID: Integer;
    FFindArea: TBCEditorLinesArea;
    FFindDialog: TFindDialog;
    FFindPosition: TBCEditorLinesPosition;
    FFindState: (fsRequested, fsWrappedAround, fsAllAreas);
    FFmtLines: Boolean;
    FGotoLineDialog: TGotoLineDialog;
    FHideSelection: Boolean;
    FHintWindow: THintWindow;
    FHookedCommandHandlers: TBCEditorHookedCommandHandlers;
    FHorzScrollBarDivider: Integer;
    FIMEStatus: LPARAM;
    FInsertPos: TPoint;
    FInsertPosBitmap: TGPCachedBitmap;
    FInsertPosCache: TBitmap;
    FLastCursorPoint: TPoint;
    FLastDoubleClickTime: Cardinal;
    FLastLineInBuiltRows: Integer;
    FLastSearch: (lsFind, lsReplace);
    FLastSearchData: TBCEditorCommandData;
    FLeftMargin: TBCEditorLeftMargin;
    FLeftMarginBorderWidth: Integer;
    FLeftMarginWidth: Integer;
    FLineBreakSignWidth: Integer;
    FLineHeight: Integer;
    FLines: TBCEditorLines;
    FLineNumbersWidth: Integer;
    FLineStateWidth: Integer;
    FMarksPanelPopupMenu: TPopupMenu;
    FMarksPanelWidth: Integer;
    FMaxDigitWidth: Integer;
    FMetrics: TMetrics;
    FMinusSignWidth: Integer;
    FMouseCapture: TMouseCapture;
    FMouseDownPoint: TPoint;
    FNoParentNotify: Boolean;
    FOldClientRect: TRect;
    FOldActiveLine: Integer;
    FOldSelArea: TBCEditorLinesArea;
    FOnCaretChanged: TBCEditorCaretChangedEvent;
    FOnChange: TNotifyEvent;
    FOnCompletionProposalClose: TBCEditorCompletionProposalCloseEvent;
    FOnCompletionProposalShow: TBCEditorCompletionProposalShowEvent;
    FOnCompletionProposalValidate: TBCEditorCompletionProposalValidateEvent;
    FOnFindExecuted: TBCEditorFindExecutedEvent;
    FOnFindWrapAround: TBCEditorFindWrapAroundEvent;
    FOnHint: TBCEditorHintEvent;
    FOnMarksPanelClick: TBCEditorMarksPanelClick;
    FOnModified: TNotifyEvent;
    FOnReplacePrompt: TBCEditorReplacePromptEvent;
    FOnSelChanged: TNotifyEvent;
    FOptions: TBCEditorOptions;
    FOverlays: TOverlays;
    FPaintHelper: TCustomBCEditor.TPaintHelper;
    FParentWnd: HWND;
    FPopupMenu: HMENU;
    FReadOnly: Boolean;
    FReplaceAction: TBCEditorReplaceAction;
    FReplaceDialog: TReplaceDialog;
    FRows: TCustomBCEditor.TRows;
    FRowsWanted: TRowsWanted;
    FScrollBars: UITypes.TScrollStyle;
    FScrollingBitmap: TGPCachedBitmap;
    FScrollingBitmapHeight: Integer;
    FScrollingBitmapWidth: Integer;
    FScrollingEnabled: Boolean;
    FScrollingPoint: TPoint;
    FScrollingRect: TRect;
    FSelectedCaseCycle: TBCEditorCase;
    FSelectedCaseText: string;
    FSelectionOptions: TBCEditorSelectionOptions;
    FSpaceWidth: Integer;
    FSpecialCharsNullText: string;
    FSpecialCharsSpaceText: string;
    FState: TState;
    FSyncEditButtonHotBitmap: TGPCachedBitmap;
    FSyncEditButtonNormalBitmap: TGPCachedBitmap;
    FSyncEditButtonPressedBitmap: TGPCachedBitmap;
    FSyncEditButtonRect: TRect;
    FSyncEditOptions: TBCEditorSyncEditOptions;
    FTabSignWidth: Integer;
    FTabs: TBCEditorTabs;
    FTextEntryMode: TBCEditorTextEntryMode;
    FTextPos: TPoint;
    FTopRow: Integer;
    FUCCVisible: Boolean;
    FUsableRows: Integer;
    FUpdateCount: Integer;
    FVertScrollBarDivider: Integer;
    FVisibleRows: Integer;
    FWantReturns: Boolean;
    FWantTabs: Boolean;
    FWheelScrollChars: UINT;
    FWindowProducedMessage: Boolean;
    FWordWrap: Boolean;
    procedure AskReplaceText(ASender: TObject; const AArea: TBCEditorLinesArea;
      const ABackwards: Boolean; const AReplaceText: string; var AAction: TBCEditorReplaceAction);
    function AskSearchWrapAround(const AData: PBCEditorCommandDataFind): Boolean;
    procedure BookmarksChanged(ASender: TObject);
    procedure BuildRows(const AThread: TBuildRowsThread; const APaintHelper: TPaintHelper);
    function ClientToLines(const X, Y: Integer; const AForCaret: Boolean = False): TBCEditorLinesPosition; {$IFNDEF Debug} inline; {$ENDIF}
    function ClientToRows(const X, Y: Integer; const AForCaret: Boolean = False): TBCEditorRowsPosition;
    procedure CMDoubleBufferedChanged(var AMessage: TMessage); message CM_DOUBLEBUFFEREDCHANGED;
    procedure CMSysFontChanged(var AMessage: TMessage); message CM_SYSFONTCHANGED;
    procedure CaretChanged(ASender: TObject);
    function CodeFoldingCollapsableFoldRangeForLine(const ALine: Integer): TBCEditorCodeFoldingRanges.TRange;
    function CodeFoldingFoldRangeForLineTo(const ALine: Integer): TBCEditorCodeFoldingRanges.TRange;
    procedure CollapseCodeFoldingRange(const ARange: TBCEditorCodeFoldingRanges.TRange);
    procedure ColorsChanged(ASender: TObject);
    procedure DeleteChar;
    procedure DeleteLastWordOrBOL(const ACommand: TBCEditorCommand);
    procedure DeleteLine;
    procedure DeleteLineFromRows(const ALine: Integer);
    procedure DoBackspace();
    procedure DoBlockComment;
    procedure DoBOL(const ASelectionCommand: Boolean);
    procedure DoChar(const AData: PBCEditorCommandDataChar);
    procedure DoCopyToClipboard();
    procedure DoCutToClipboard();
    procedure DoDeleteToEOL();
    procedure DoDeleteWord();
    procedure DoDropOLE(const AData: PBCEditorCommandDataDropOLE);
    procedure DoEOF(const ACommand: TBCEditorCommand); {$IFNDEF Debug} inline; {$ENDIF}
    procedure DoEOL(const ASelectionCommand: Boolean);
    procedure DoBOF(const ACommand: TBCEditorCommand); {$IFNDEF Debug} inline; {$ENDIF}
    function DoFindBackwards(const AData: PBCEditorCommandDataFind): Boolean;
    procedure DoFindFirst(const AData: PBCEditorCommandDataFind);
    function DoFindForewards(const AData: PBCEditorCommandDataFind): Boolean;
    procedure DoInsertText(const AText: string);
    procedure DoLineComment();
    procedure DoPageUpOrDown(const ACommand: TBCEditorCommand);
    procedure DoPageTopOrBottom(const ACommand: TBCEditorCommand);
    procedure DoPosition(const AData: PBCEditorCommandDataPosition);
    procedure DoReplace(const AData: TBCEditorCommandData);
    procedure DoReturnKey();
    procedure DoScroll(const ACommand: TBCEditorCommand);
    procedure DoScrollTo(const AData: TBCEditorCommandData);
    procedure DoSelectAll();
    procedure DoSelection(const AData: PBCEditorCommandDataSelection);
    procedure DoShowFind(const First: Boolean);
    procedure DoShowGotoLine();
    procedure DoShowReplace();
    procedure DoSetBookmark(const ACommand: TBCEditorCommand);
    procedure DoTabKey(const ACommand: TBCEditorCommand);
    procedure DoText(const AData: PBCEditorCommandDataText);
    procedure DoToggleSelectedCase(const ACommand: TBCEditorCommand);
    procedure DoUnselect();
    procedure DoUpOrDown(const ARows: Integer; const ASelect: Boolean);
    procedure DoWordLeft(const ACommand: TBCEditorCommand);
    procedure DoWordRight(const ACommand: TBCEditorCommand);
    procedure EMCanUndo(var AMessage: TMessage); message EM_CANUNDO;
    procedure EMCharFromPos(var AMessage: TMessage); message EM_CHARFROMPOS;
    procedure EMEmptyUndoBuffer(var AMessage: TMessage); message EM_EMPTYUNDOBUFFER;
    procedure EMFmtLines(var AMessage: TMessage); message EM_FMTLINES;
    procedure EMGetFirstVisible(var AMessage: TMessage); message EM_GETFIRSTVISIBLELINE;
    procedure EMGetHandle(var AMessage: TMessage); message EM_GETHANDLE;
    procedure EMGetIMEStatus(var AMessage: TMessage); message EM_GETIMESTATUS;
    procedure EMGetLine(var AMessage: TMessage); message EM_GETLINE;
    procedure EMGetLineCount(var AMessage: TMessage); message EM_GETLINECOUNT;
    procedure EMGetModify(var AMessage: TMessage); message EM_GETMODIFY;
    procedure EMGetRect(var AMessage: TMessage); message EM_GETRECT;
    procedure EMGetSel(var AMessage: TMessage); message EM_GETSEL;
    procedure EMGetThumb(var AMessage: TMessage); message EM_GETTHUMB;
    procedure EMLineFromChar(var AMessage: TMessage); message EM_LINEFROMCHAR;
    procedure EMLineIndex(var AMessage: TMessage); message EM_LINEINDEX;
    procedure EMLineLength(var AMessage: TMessage); message EM_LINELENGTH;
    procedure EMLineScroll(var AMessage: TMessage); message EM_LINESCROLL;
    procedure EMPosFromChar(var AMessage: TMessage); message EM_POSFROMCHAR;
    procedure EMReplaceSel(var AMessage: TMessage); message EM_REPLACESEL;
    procedure EMScroll(var AMessage: TMessage); message EM_SCROLL;
    procedure EMScrollCaret(var AMessage: TMessage); message EM_SCROLLCARET;
    procedure EMSetIMEStatus(var AMessage: TMessage); message EM_SETIMESTATUS;
    procedure EMSetModify(var AMessage: TMessage); message EM_SETMODIFY;
    procedure EMSetReadOnly(var AMessage: TMessage); message EM_SETREADONLY;
    procedure EMSetSel(var AMessage: TMessage); message EM_SETSEL;
    procedure EMSetTabStop(var AMessage: TMessage); message EM_SETTABSTOPS;
    procedure EMUndo(var AMessage: TMessage); message EM_UNDO;
    procedure ExpandCodeFoldingRange(const ARange: TBCEditorCodeFoldingRanges.TRange);
    procedure FindDialogClose(Sender: TObject);
    procedure FindDialogFind(Sender: TObject);
    procedure FindExecuted(const AData: Pointer);
    procedure FontChanged(ASender: TObject);
    function GetCanPaste(): Boolean; {$IFNDEF Debug} inline; {$ENDIF}
    function GetCanRedo(): Boolean; {$IFNDEF Debug} inline; {$ENDIF}
    function GetCanUndo(): Boolean; {$IFNDEF Debug} inline; {$ENDIF}
    function GetCaretPos(): TPoint;
    function GetCharAt(APos: TPoint): Char; {$IFNDEF Debug} inline; {$ENDIF}
    function GetCursor(): TCursor; {$IFNDEF Debug} inline; {$ENDIF}
    function GetFindTokenData(const ARow: Integer; var ALeft: Integer;
      out ABeginRange: TBCEditorHighlighter.TRange;
      out AText: PChar; out ALength, AChar: Integer; out AColumn: Integer): Boolean;
    function GetLeadingExpandedLength(const AStr: string; const ABorder: Integer = 0): Integer;
    function GetLineIndentLevel(const ALine: Integer): Integer;
    function GetLines(): TStrings;
    function GetModified(): Boolean; {$IFNDEF Debug} inline; {$ENDIF}
    function GetSearchResultCount(): Integer; {$IFNDEF Debug} inline; {$ENDIF}
    function GetSelLength(): Integer; {$IFNDEF Debug} inline; {$ENDIF}
    function GetSelStart(): Integer; {$IFNDEF Debug} inline; {$ENDIF}
    function GetSelText(): string;
    function GetText(): string; {$IFNDEF Debug} inline; {$ENDIF}
    function GetUndoOptions(): TBCEditorUndoOptions;
    function GetWordAt(ALinesPos: TPoint): string;
    procedure HighlighterChanged(ASender: TObject);
    function IndentText(const IndentCount: Integer): string;
    procedure InsertLine();
    procedure InsertLineIntoRows(const ALine: Integer; const ANewLine: Boolean); overload;
    function InsertLineIntoRows(const APaintHelper: TPaintHelper;
      const AThread: TBuildRowsThread; const ALine, ARow: Integer): Integer; overload;
    procedure InvalidateCaret();
    procedure InvalidateClient();
    procedure InvalidateCodeFolding();
    procedure InvalidateOverlays();
    procedure InvalidateRect(const ARect: TRect; const AOverlay: Boolean = False); {$IFNDEF Debug} inline; {$ENDIF}
    procedure InvalidateRows();
    procedure InvalidateScrollBars();
    procedure InvalidateSyncEdit();
    procedure InvalidateSyncEditButton();
    procedure InvalidateSyncEditOverlays();
    procedure InvalidateText(const AEncloseLeftMargin: Boolean = False); overload;
    procedure InvalidateText(const ALine: Integer; const AEncloseLeftMargin: Boolean = False); overload;
    function IsColorsStored(): Boolean;
    function IsCompletionProposalStored(): Boolean;
    function IsFontStored(): Boolean;
    function IsLeftMarginStored(): Boolean;
    function LeftSpaceCount(const AText: string; AWantTabs: Boolean = False): Integer;
    function LeftTrimLength(const AText: string): Integer;
    procedure LineDeleting(ASender: TObject; const ALine: Integer);
    procedure LineInserted(ASender: TObject; const ALine: Integer);
    procedure LinesAfterUpdate(Sender: TObject);
    procedure LinesBeforeUpdate(Sender: TObject);
    procedure LinesCleared(ASender: TObject);
    procedure LinesChanged();
    procedure LinesLoaded(ASender: TObject);
    procedure LinesSelChanged(ASender: TObject);
    procedure LinesSyncEditChanged(ASender: TObject);
    procedure MarksChanged(ASender: TObject);
    procedure MatchingPairScanned(const AData: Pointer);
    procedure MoveCaretHorizontally(const AColumns: Integer; const ASelect: Boolean);
    function NextWordPosition(const ALinesPosition: TBCEditorLinesPosition): TBCEditorLinesPosition; overload;
    procedure NotifyParent(const ANotification: Word); {$IFNDEF Debug} inline; {$ENDIF}
    procedure PaintTo(const APaintHelper: TPaintHelper; const ARect: TRect; const AOverlays: Boolean = True);
    function PreviousWordPosition(const ALinesPosition: TBCEditorLinesPosition): TBCEditorLinesPosition; overload;
    function ProcessClient(const AJob: TClientJob;
      const APaintHelper: TPaintHelper; const APaintVar: PPaintVar; const AClipRect: TRect;
      const AButton: TMouseButton; const AShift: TShiftState; AMousePoint: TPoint;
      const APaintOverlays: Boolean = True): Boolean;
    function ProcessToken(const AJob: TClientJob;
      const APaintHelper: TPaintHelper;
      const APaintVar: PPaintVar; const AClipRect: TRect;
      const AButton: TMouseButton; const AShift: TShiftState; const AMousePoint: TPoint;
      var ARect: TRect;
      const ALinesPosition: TBCEditorLinesPosition;
      const ARowsPosition: TBCEditorRowsPosition;
      const AText: PChar; const ALength: Integer;
      const AToken: TBCEditorHighlighter.PTokenFind = nil;
      const ARange: TBCEditorCodeFoldingRanges.TRange = nil): Boolean;
    procedure ReplaceDialogFind(ASender: TObject);
    procedure ReplaceDialogReplace(ASender: TObject);
    procedure ReplaceExecuted(const AData: Pointer);
    function RowsToClient(ARowsPosition: TBCEditorRowsPosition;
      const AVisibleOnly: Boolean = False): TPoint;
    function RowsToLines(const ARowsPosition: TBCEditorRowsPosition): TBCEditorLinesPosition;
    function RowsToText(ARowsPosition: TBCEditorRowsPosition;
      const AVisibleOnly: Boolean = False): TPoint;
    procedure RowsWantedValid();
    procedure ScanCodeFolding();
    procedure ScrollTo(AValue: TPoint); overload; inline;
    procedure ScrollTo(AValue: TPoint; const AAlignToRow: Boolean); overload;
    procedure ScrollTo(AX, AY: Integer); overload; inline;
    procedure ScrollToPosition(const APosition: TBCEditorLinesPosition);
    procedure SetBorderStyle(const AValue: TBorderStyle);
    procedure SetCaretPos(AValue: TPoint);
    procedure SetCaretPosition(const APosition: TBCEditorLinesPosition; const ASelect: Boolean);
    procedure SetColors(AValue: TBCEditorColors);
    procedure SetCursor(AValue: TCursor);
    procedure SetHideScrollBars(AValue: Boolean);
    procedure SetHideSelection(AValue: Boolean); {$IFNDEF Debug} inline; {$ENDIF}
    procedure SetInsertPos(AValue: TPoint);
    procedure SetLeftMargin(const AValue: TBCEditorLeftMargin);
    procedure SetLines(const AValue: TStrings);
    procedure SetLinesBeginRanges(const AValue: Integer);
    procedure SetModified(const AValue: Boolean);
    procedure SetMouseCapture(const AValue: TMouseCapture);
    procedure SetOptions(const AValue: TBCEditorOptions);
    procedure SetReadOnly(const AValue: Boolean);
    procedure SetScrollBars(const AValue: UITypes.TScrollStyle);
    procedure SetSelArea(const ASelArea: TBCEditorLinesArea;
      const ACaretToBeginPosition: Boolean = False);
    procedure SetSelectedWord;
    procedure SetSelectionOptions(AValue: TBCEditorSelectionOptions);
    procedure SetSelLength(AValue: Integer);
    procedure SetSelStart(AValue: Integer);
    procedure SetSelText(const AValue: string);
    procedure SetSyncEditOptions(AValue: TBCEditorSyncEditOptions);
    procedure SetTabs(const AValue: TBCEditorTabs);
    procedure SetText(const AValue: string); {$IFNDEF Debug} inline; {$ENDIF}
    procedure SetTextPos(const AValue: TPoint); overload;
    procedure SetTextPos(AX, AY: Integer); overload; inline;
    procedure SetTopRow(const AValue: Integer);
    procedure SetUndoOptions(AOptions: TBCEditorUndoOptions);
    procedure SetWantReturns(const AValue: Boolean); {$IFNDEF Debug} inline; {$ENDIF}
    procedure SetWordBlock(const ALinesPosition: TBCEditorLinesPosition);
    procedure SetWordWrap(const AValue: Boolean);
    procedure SyncEditActivated(const AData: Pointer);
    procedure SyncEditChecked(const AData: Pointer);
    procedure TabsChanged(ASender: TObject);
    function TokenColumns(const AText: PChar; const ALength, AColumn: Integer): Integer; {$IFNDEF Debug} inline; {$ENDIF}
    function TokenWidth(const APaintHelper: TPaintHelper; const ALine: Integer;
      const AText: PChar; const ALength: Integer;
      const AColumn: Integer; const AToken: TBCEditorHighlighter.PTokenFind): Integer; // inline takes the double time. Why???
    procedure UMFindAllAreas(var AMessage: TMessage); message UM_FIND_ALLAREAS;
    procedure UMFindWrapAround(var AMessage: TMessage); message UM_FIND_WRAPAROUND;
    procedure UMFreeCompletionProposalPopup(var AMessage: TMessage); message UM_FREE_COMPLETIONPROPOSALPOPUP;
    procedure WMRowAvailable(var AMessage: TMessage); message UM_ROWSAVAILABLE;
    procedure UMUpdateScrollBars(var AMessage: TMessage); message UM_UPDATE_SCROLLBARS;
    procedure UpdateCaret();
    procedure UpdateCursor(); {$IFNDEF Debug} inline; {$ENDIF}
    procedure UpdateLineInRows(const ALine: Integer);
    procedure UpdateMetrics();
    procedure UpdateScrollBars();
    procedure WMClear(var AMessage: TWMClear); message WM_CLEAR;
    procedure WMCommand(var AMessage: TWMCommand); message WM_COMMAND;
    procedure WMContextMenu(var AMessage: TWMContextMenu); message WM_CONTEXTMENU;
    procedure WMCopy(var AMessage: TWMCopy); message WM_COPY;
    procedure WMCut(var AMessage: TWMCut); message WM_CUT;
    procedure WMEraseBkgnd(var AMessage: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMGetDlgCode(var AMessage: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMGetText(var AMessage: TWMGetText); message WM_GETTEXT;
    procedure WMGetTextLength(var AMessage: TWMGetTextLength); message WM_GETTEXTLENGTH;
    procedure WMHScroll(var AMessage: TWMScroll); message WM_HSCROLL;
    procedure WMIMEChar(var AMessage: TMessage); message WM_IME_CHAR;
    procedure WMIMEComposition(var AMessage: TMessage); message WM_IME_COMPOSITION;
    procedure WMIMENotify(var AMessage: TMessage); message WM_IME_NOTIFY;
    procedure WMKillFocus(var AMessage: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMMouseHWheel(var AMessage: TWMMouseWheel); message WM_MOUSEHWHEEL;
    procedure WMNCPaint(var AMessage: TWMNCPaint); message WM_NCPAINT;
    procedure WMPaint(var AMessage: TWMPaint); message WM_PAINT;
    procedure WMPaste(var AMessage: TWMPaste); message WM_PASTE;
    procedure WMPrint(var AMessage: TWMPrint); message WM_PRINT;
    procedure WMSetCursor(var AMessage: TWMSetCursor); message WM_SETCURSOR;
    procedure WMSetFocus(var AMessage: TWMSetFocus); message WM_SETFOCUS;
    procedure WMSettingChange(var AMessage: TWMSettingChange); message WM_SETTINGCHANGE;
    procedure WMSetText(var AMessage: TWMSetText); message WM_SETTEXT;
    procedure WMStyleChanged(var AMessage: TWMStyleChanged); message WM_STYLECHANGED;
    procedure WMSysChar(var AMessage: TMessage); message WM_SYSCHAR;
    procedure WMTimer(var Msg: TWMTimer); message WM_TIMER;
    procedure WMUndo(var AMessage: TWMUndo); message WM_UNDO;
    procedure WMVScroll(var AMessage: TWMScroll); message WM_VSCROLL;
  protected // IDropSource
    function GiveFeedback(dwEffect: Longint): HResult; stdcall;
    function QueryContinueDrag(fEscapePressed: BOOL; grfKeyState: Longint): HResult; stdcall;
  protected // IDropTarget
    function DragEnter(const dataObj: IDataObject; grfKeyState: Longint;
      pt: TPoint; var dwEffect: Longint): HResult; stdcall;
    function DragLeave(): HResult; stdcall;
    function DragOver(grfKeyState: Longint; pt: TPoint; var dwEffect: Longint): HResult; reintroduce; overload; stdcall;
    function Drop(const dataObj: IDataObject; grfKeyState: Longint; pt: TPoint;
      var dwEffect: Longint): HResult; stdcall;
  protected
    procedure Change(); virtual;
    procedure ChangeScale(M, D: Integer); override;
    procedure ClearUndo();
    procedure CollapseCodeFoldingLevel(const AFirstLevel: Integer; const ALastLevel: Integer);
    function CollapseCodeFoldingLines(const AFirstLine: Integer = -1; const ALastLine: Integer = -1): Integer;
    function CreateLines(): BCEditor.Lines.TBCEditorLines;
    procedure CreateParams(var AParams: TCreateParams); override;
    procedure CreateWnd(); override;
    function DeleteBookmark(const ALine: Integer; const AIndex: Integer): Boolean; overload;
    procedure DestroyWnd(); override;
    procedure DoBlockIndent(const ACommand: TBCEditorCommand);
    procedure DoCompletionProposal(); virtual;
    function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    procedure DoSyncEdit();
    procedure DoTripleClick;
    procedure DragCanceled(); override;
    procedure DragOver(ASource: TObject; X, Y: Integer; AState: TDragState; var AAccept: Boolean); overload; override;
    procedure ExpandCodeFoldingLevel(const AFirstLevel: Integer; const ALastLevel: Integer);
    function ExpandCodeFoldingLines(const AFirstLine: Integer = -1; const ALastLine: Integer = -1): Integer;
    function GetBookmark(const AIndex: Integer; var ALinesPosition: TBCEditorLinesPosition): Boolean;
    function GetMarks(): TBCEditorLines.TMarkList; inline;
    procedure GotoBookmark(const AIndex: Integer);
    procedure GotoNextBookmark;
    procedure GotoPreviousBookmark;
    procedure InvalidateMatchingPair();
    function IsCommentChar(const AChar: Char): Boolean;
    function IsEmptyChar(const AChar: Char): Boolean; {$IFNDEF Debug} inline; {$ENDIF}
    function IsWordBreakChar(const AChar: Char): Boolean; {$IFNDEF Debug} inline; {$ENDIF}
    procedure KeyDown(var AKey: Word; AShift: TShiftState); override;
    procedure KeyPress(var AKey: Char); override;
    procedure LeftMarginChanged(ASender: TObject);
    function LinesToRows(const ALinesPosition: TBCEditorLinesPosition): TBCEditorRowsPosition;
    procedure LineUpdated(ASender: TObject; const ALine: Integer); virtual;
    procedure MouseDown(AButton: TMouseButton; AShift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(AShift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(AButton: TMouseButton; AShift: TShiftState; X, Y: Integer); override;
    procedure Paint(); override;
    procedure ReadState(Reader: TReader); override;
    procedure Resize(); override;
    procedure ScanCodeFoldingRanges(); virtual;
    procedure SetBookmark(const AIndex: Integer; const ALinesPosition: TBCEditorLinesPosition);
    procedure SetLineColor(const ALine: Integer; const AForegroundColor, ABackgroundColor: TColor);
    procedure SetMark(const AIndex: Integer; const ALinesPosition: TBCEditorLinesPosition;
      const AImageIndex: Integer);
    procedure SetParent(AParent: TWinControl); override;
    procedure SetUndoOption(const AOption: TBCEditorUndoOption; const AEnabled: Boolean);
    procedure SetUpdateState(AUpdating: Boolean); virtual;
    function SplitTextIntoWords(AStringList: TStrings; const ACaseSensitive: Boolean): string;
    function WordBegin(const ALinesPosition: TBCEditorLinesPosition): TBCEditorLinesPosition; overload;
    function WordEnd(): TBCEditorLinesPosition; overload; {$IFNDEF Debug} inline; {$ENDIF}
    function WordEnd(const ALinesPosition: TBCEditorLinesPosition): TBCEditorLinesPosition; overload;
    property AllCodeFoldingRanges: TBCEditorCodeFoldingAllRanges read FAllCodeFoldingRanges;
    property AfterProcessCommand: TBCEditorAfterProcessCommandEvent read FAfterProcessCommand write FAfterProcessCommand;
    property BeforeProcessCommand: TBCEditorBeforeProcessCommandEvent read FBeforeProcessCommand write FBeforeProcessCommand;
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    property CanPaste: Boolean read GetCanPaste;
    property CanRedo: Boolean read GetCanRedo;
    property CanUndo: Boolean read GetCanUndo;
    property CaretPos: TPoint read GetCaretPos write SetCaretPos;
    property CharAt[Pos: TPoint]: Char read GetCharAt;
    property Colors: TBCEditorColors read FColors write SetColors stored IsColorsStored;
    property CompletionProposal: TBCEditorCompletionProposal read FCompletionProposal write FCompletionProposal stored IsCompletionProposalStored;
    property Cursor: TCursor read GetCursor write SetCursor;
    property Font stored IsFontStored;
    property HideScrollBars: Boolean read FHideScrollBars write SetHideScrollBars default True;
    property HideSelection: Boolean read FHideSelection write SetHideSelection default True;
    property Highlighter: TBCEditorHighlighter read FHighlighter;
    property InsertPos: TPoint read FInsertPos write SetInsertPos;
    property LeftMargin: TBCEditorLeftMargin read FLeftMargin write SetLeftMargin stored IsLeftMarginStored;
    property LineHeight: Integer read FLineHeight;
    property Lines: TStrings read GetLines write SetLines;
    property Marks: TBCEditorLines.TMarkList read GetMarks;
    property MarksPanelPopupMenu: TPopupMenu read FMarksPanelPopupMenu write FMarksPanelPopupMenu;
    property Modified: Boolean read GetModified write SetModified;
    property MouseCapture: TMouseCapture read FMouseCapture write SetMouseCapture;
    property OnCaretChanged: TBCEditorCaretChangedEvent read FOnCaretChanged write FOnCaretChanged;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnCompletionProposalClose: TBCEditorCompletionProposalCloseEvent read FOnCompletionProposalClose write FOnCompletionProposalClose;
    property OnCompletionProposalShow: TBCEditorCompletionProposalShowEvent read FOnCompletionProposalShow write FOnCompletionProposalShow;
    property OnCompletionProposalValidate: TBCEditorCompletionProposalValidateEvent read FOnCompletionProposalValidate write FOnCompletionProposalValidate;
    property OnFindExecuted: TBCEditorFindExecutedEvent read FOnFindExecuted write FOnFindExecuted;
    property OnFindWrapAround: TBCEditorFindWrapAroundEvent read FOnFindWrapAround write FOnFindWrapAround;
    property OnHint: TBCEditorHintEvent read FOnHint write FOnHint;
    property OnMarksPanelClick: TBCEditorMarksPanelClick read FOnMarksPanelClick write FOnMarksPanelClick;
    property OnModified: TNotifyEvent read FOnModified write FOnModified;
    property OnReplacePrompt: TBCEditorReplacePromptEvent read FOnReplacePrompt write FOnReplacePrompt;
    property OnSelChanged: TNotifyEvent read FOnSelChanged write FOnSelChanged;
    property Options: TBCEditorOptions read FOptions write SetOptions default DefaultOptions;
    property PaintHelper: TCustomBCEditor.TPaintHelper read FPaintHelper;
    property ParentColor default False;
    property ParentFont default False;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property ScrollBars: UITypes.TScrollStyle read FScrollBars write SetScrollBars default ssBoth;
    property SearchResultCount: Integer read GetSearchResultCount;
    property SelectionOptions: TBCEditorSelectionOptions read FSelectionOptions write SetSelectionOptions default DefaultSelectionOptions;
    property SelLength: Integer read GetSelLength write SetSelLength;
    property SelStart: Integer read GetSelStart write SetSelStart;
    property SelText: string read GetSelText write SetSelText;
    property SyncEditOptions: TBCEditorSyncEditOptions read FSyncEditOptions write SetSyncEditOptions default DefaultSyncEditOptions;
    property Tabs: TBCEditorTabs read FTabs write SetTabs;
    property TabStop default True;
    property Text: string read GetText write SetText;
    property TextEntryMode: TBCEditorTextEntryMode read FTextEntryMode write FTextEntryMode default temInsert;
    property TextPos: TPoint read FTextPos write ScrollTo;
    property TopRow: Integer read FTopRow write SetTopRow;
    property UndoOptions: TBCEditorUndoOptions read GetUndoOptions write SetUndoOptions default DefaultUndoOptions;
    property UpdateCount: Integer read FUpdateCount;
    property VisibleRows: Integer read FVisibleRows;
    property WantReturns: Boolean read FWantReturns write SetWantReturns default True;
    property WantTabs: Boolean read FWantTabs write FWantTabs default True;
    property WordAt[ATextPos: TPoint]: string read GetWordAt;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default False;
  public
    procedure ActivateHint(const X, Y: Integer; const AHint: string);
    procedure AddHighlighterKeywords(AStringList: TStrings);
    procedure Assign(ASource: TPersistent); override;
    procedure BeginUndoBlock(); deprecated 'Use Lines.EndUpdate()'; // 2017-07-12
    procedure BeginUpdate();
    function CharIndexToPos(const ACharIndex: Integer): TPoint; {$IFNDEF Debug} inline; {$ENDIF}
    procedure Clear(); virtual; deprecated 'Use Lines.Clear()';
    function ClientToPos(const X, Y: Integer): TPoint; {$IFNDEF Debug} inline; {$ENDIF}
    function ClientToText(const X, Y: Integer): TPoint; deprecated 'Use ClientToPos'; // 2017-05-13
    function CharAtCursor(): Char; deprecated 'Use CharAt[CaretPos]'; // 2017-04-05
    procedure CommandProcessor(ACommand: TBCEditorCommand; AChar: Char; AData: Pointer); deprecated 'Use ProcessCommand'; // 2017-08-11
    procedure CopyToClipboard();
    constructor Create(AOwner: TComponent); override;
    procedure CutToClipboard();
    destructor Destroy(); override;
    procedure DoRedo(); deprecated 'Use Redo()'; // 2017-02-12
    procedure DoUndo(); deprecated 'Use Undo()'; // 2017-02-12
    procedure DragDrop(ASource: TObject; X, Y: Integer); override;
    procedure EndUndoBlock(); deprecated 'Use Lines.EndUpdate()'; // 2017-07-12
    procedure EndUpdate();
    function ExecuteAction(Action: TBasicAction): Boolean; override;
    procedure ExportToHTML(const AFileName: string; const ACharSet: string = ''; AEncoding: TEncoding = nil); overload;
    procedure ExportToHTML(AStream: TStream; const ACharSet: string = ''; AEncoding: TEncoding = nil); overload;
    procedure LoadFromFile(const AFileName: string; AEncoding: TEncoding = nil); deprecated 'Use Lines.LoadFromFile'; // 2017-03-10
    procedure LoadFromStream(AStream: TStream; AEncoding: TEncoding = nil); deprecated 'Use Lines.LoadFromStream'; // 2017-03-10
    procedure PasteFromClipboard();
    function PosToCharIndex(const APos: TPoint): Integer;
    function ProcessCommand(const ACommand: TBCEditorCommand; const AData: TBCEditorCommandData = nil): Boolean;
    procedure Redo(); {$IFNDEF Debug} inline; {$ENDIF}
    procedure RegisterCommandHandler(const AProc: Pointer; const AHandlerData: Pointer); overload;
    procedure RegisterCommandHandler(const AProc: TBCEditorHookedCommandObjectProc); overload;
    procedure SaveToFile(const AFileName: string; AEncoding: TEncoding = nil);
    procedure SaveToStream(AStream: TStream; AEncoding: TEncoding = nil);
    procedure SelectAll();
    function SelectedText(): string; deprecated 'Use SelText'; // 2017-03-16
    function SelectionAvailable: Boolean; deprecated 'Use SelLength <> 0'; // 2017-07-16
    procedure SetFocus(); override;
    procedure Sort(const ASortOrder: TBCEditorSortOrder = soAsc; const ACaseSensitive: Boolean = False);
    function TextBetween(const ABeginPosition, AEndPosition: TBCEditorLinesPosition): string; deprecated 'Use SelStart := PosToCharIndex(BeginPos); SelLength := SelStart + PosToCharIndex(EndPos); Result := SelText;'; // 2017-07-23
    function TextCaretPosition(): TBCEditorLinesPosition; deprecated 'Use CaretPos'; // 2017-02-12
    procedure ToggleSelectedCase(const ACase: TBCEditorCase = cNone);
    procedure Undo(); {$IFNDEF Debug} inline; {$ENDIF}
    function UpdateAction(Action: TBasicAction): Boolean; override;
    procedure UnregisterCommandHandler(const AProc: Pointer;
      const AHandlerData: Pointer); overload;
    procedure UnregisterCommandHandler(const AProc: TBCEditorHookedCommandObjectProc); overload;
    procedure WndProc(var AMessage: TMessage); override;
    function WordAtCursor(): string; deprecated 'Use WordAt[CaretPos]'; // 2017-03-13
  end;

type
  TBCEditor = class(TCustomBCEditor)
  private
    function GetLines(): TStrings;
    function IsLinesStored(): Boolean;
    procedure SetLines(const AValue: TStrings);
  public
    property CanPaste;
    property CanRedo;
    property CanUndo;
    property Canvas;
    property CaretPos;
    property CharAt;
    property Highlighter;
    property InsertPos;
    property Marks;
    property Modified;
    property SearchResultCount;
    property SelLength;
    property SelStart;
    property SelText;
    property Text;
    property TextEntryMode;
    property WordAt;
  published
    property AfterProcessCommand;
    property Align;
    property Anchors;
    property BeforeProcessCommand;
    property BorderStyle;
    property Color default clWindow;
    property Colors;
    property CompletionProposal;
    property Constraints;
    property Ctl3D;
    property DoubleBuffered default True;
    property Enabled;
    property Font;
    property Height;
    property HideScrollBars;
    property HideSelection;
    property ImeMode;
    property ImeName;
    property LeftMargin;
    property Lines: TStrings read GetLines write SetLines stored IsLinesStored;
    property OnCaretChanged;
    property OnChange;
    property OnClick;
    property OnCompletionProposalClose;
    property OnCompletionProposalShow;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnHint;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMarksPanelClick;
    property OnModified;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnReplacePrompt;
    property OnSelChanged;
    property OnStartDock;
    property Options;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ReadOnly;
    property SelectionOptions;
    property ShowHint;
    property SyncEditOptions;
    property TabOrder;
    property Tabs;
    property TabStop;
    property Tag;
    property UndoOptions;
    property Visible;
    property WantTabs;
    property WantReturns;
    property Width;
    property WordWrap;
  end;

  EBCEditorBaseException = class(Exception);

implementation {***************************************************************}

{$R BCEditor.res}

uses
  ShellAPI, Imm, CommCtrl,
  Math, Types, Character, RegularExpressions, ComObj, SysConst,
  Clipbrd, Themes, ImgList,
  BCEditor.Language, BCEditor.ExportHTML;

resourcestring
  SBCEditorLineIsNotVisible = 'Line %d is not visible';
  SBCEditorOverlayInvalidArea = 'Overlay area invalid';
  SBCEditorOverlayOverlap = 'Overlay overlap';

type
  TUnprotectedWinControl = class(TWinControl);

const
  InvalidRect: TRect = ( Left: -1; Top: -1; Right: -1; Bottom: -1 );
  InvalidPos: TPoint = ( X: -1; Y: -1 );

  tiCodeFolding = 0;
  tiShowHint = 1;
  tiScrolling = 2;
  tiScroll = 3;
  tiCompletionProposal = 4;

  GClientRefreshTime = 40 {ms}; // Time between two client area refreshs

var
  GLineWidth: Integer;
  GImmEnabled: Boolean;
  GPadding: Integer;

function EnumFontsFamiliesProc(var lpelf: TEnumLogFont; var lpntm: TNewTextMetric;
  FontType: Integer; lParam: LPARAM): Integer; stdcall;
begin;
  Result := Integer(lpelf.elfLogFont.lfPitchAndFamily and FIXED_PITCH <> 0);
end;

{ TCustomBCEditor.TDropData ***************************************************}

function TCustomBCEditor.TDropData.Clone(out Enum: IEnumFormatEtc): HResult;
begin
  Enum := TDropData.Create(FEditor);
  Result := S_OK;
end;

constructor TCustomBCEditor.TDropData.Create(const AEditor: TCustomBCEditor);
begin
  inherited Create();

  FEditor := AEditor;
end;

function TCustomBCEditor.TDropData.DAdvise(const formatetc: TFormatEtc; advf: Longint;
  const advSink: IAdviseSink; out dwConnection: Longint): HResult;
begin
  Result := OLE_E_ADVISENOTSUPPORTED;
end;

function TCustomBCEditor.TDropData.DUnadvise(dwConnection: Longint): HResult;
begin
  Result := OLE_E_ADVISENOTSUPPORTED;
end;

function TCustomBCEditor.TDropData.EnumDAdvise(out enumAdvise: IEnumStatData): HResult;
begin
  Result := OLE_E_ADVISENOTSUPPORTED;
end;

function TCustomBCEditor.TDropData.EnumFormatEtc(dwDirection: Longint; out enumFormatEtc:
  IEnumFormatEtc): HResult;
begin
  case (dwDirection) of
    DATADIR_GET:
      begin
        enumFormatEtc := Self;
        Result := S_OK;
      end;
    else
      raise ERangeError.Create(SRangeError);
  end;
end;

function TCustomBCEditor.TDropData.GetCanonicalFormatEtc(const formatetc: TFormatEtc;
  out formatetcOut: TFormatEtc): HResult;
begin
  MoveMemory(@formatetcOut, @formatetc, SizeOf(formatetc));
  formatetcOut.ptd := nil;
  Result := DATA_S_SAMEFORMATETC;
end;

function TCustomBCEditor.TDropData.GetData(const formatetcIn: TFormatEtc; out medium: TStgMedium):
  HResult;
var
  LText: string;
begin
  if (formatetcin.lindex <> -1) then
    Result := DV_E_LINDEX
  else if (formatetcin.tymed <> TYMED_HGLOBAL) then
    Result := DV_E_TYMED
  else
  begin
    Result := S_OK;
    case (formatetcin.cfFormat) of
      CF_UNICODETEXT: LText := FEditor.SelText;
      else Result := DV_E_FORMATETC;
    end;

    if (Result = S_OK) then
    begin
      FillChar(medium, SizeOf(medium), 0);
      medium.tymed := TYMED_HGLOBAL;
      medium.hGlobal := GlobalAlloc(GMEM_MOVEABLE + GMEM_DDESHARE, SizeOf(LText[1]) * Length(LText));
      MoveMemory(GlobalLock(medium.hGlobal), PChar(LText), Length(LText) * SizeOf(LText[1]));
    end;
  end;
end;

function TCustomBCEditor.TDropData.GetDataHere(const formatetc: TFormatEtc; out medium: TStgMedium):
  HResult;
var
  LText: string;
begin
  LText := FEditor.SelText;

  if (formatetc.lindex <> -1) then
    Result := DV_E_LINDEX
  else if (formatetc.tymed <> TYMED_HGLOBAL) then
    Result := DV_E_TYMED
  else if (GlobalSize(medium.hGlobal) < SIZE_T(Length(LText) * SizeOf(LText[1]))) then
    Result := STG_E_MEDIUMFULL
  else
  begin
    MoveMemory(GlobalLock(medium.hGlobal), PChar(LText), Length(LText) * SizeOf(LText[1]));
    Result := S_OK;
  end;
end;

function TCustomBCEditor.TDropData.Next(celt: Longint; out elt; pceltFetched: PLongint): HResult;
type
  TFormatEtcArray2 = array [0 .. $FFFF] of FORMATETC;
var
  Formats: ^TFormatEtcArray2;
begin
  if ((celt = 0) or (celt > 1) and not Assigned(pceltFetched)
    or (FEnumFormatEtcIndex = 1)) then
    Result := S_FALSE
  else
  begin
    Formats := @elt;

    case (FEnumFormatEtcIndex) of
      0:
        begin
          Formats^[0].cfFormat := CF_UNICODETEXT;
          Formats^[0].ptd := nil;
          Formats^[0].dwAspect := DVASPECT_CONTENT;
          Formats^[0].lindex := -1;
          Formats^[0].tymed := TYMED_HGLOBAL;
        end;
      else
        raise ERangeError.Create('Index: ' + IntToStr(FEnumFormatEtcIndex));
    end;
    Inc(FEnumFormatEtcIndex);
    if (Assigned(pceltFetched)) then
      Inc(pceltFetched^);

    if (celt = 1) then
      Result := S_OK
    else
      Result := Next(celt - 1, Formats^[1], pceltFetched);
  end;
end;

function TCustomBCEditor.TDropData.QueryGetData(const formatetc: TFormatEtc): HResult;
var
  LFormat: TFormatEtc;
begin
  if (formatetc.lindex <> -1) then
    Result := DV_E_LINDEX
  else if (formatetc.tymed <> TYMED_HGLOBAL) then
    Result := DV_E_TYMED
  else
  begin
    Reset();
    repeat
      Result := Next(1, LFormat, nil);
    until ((Result <> S_OK) or (LFormat.cfFormat = formatetc.cfFormat));

    if (Result = S_FALSE) then
      Result := DV_E_FORMATETC;
  end;
end;

function TCustomBCEditor.TDropData.Reset(): HResult;
begin
  FEnumFormatEtcIndex := 0;

  Result := S_OK;
end;

function TCustomBCEditor.TDropData.SetData(const formatetc: TFormatEtc; var medium: TStgMedium;
  fRelease: BOOL): HResult;
begin
  Result := E_FAIL;
end;

function TCustomBCEditor.TDropData.Skip(celt: Longint): HResult;
begin
  Result := S_FALSE;
end;

{ TCustomBCEditor.TBuildRowsThread ********************************************}

procedure TCustomBCEditor.TBuildRowsThread.Execute();
begin
  FEditor.BuildRows(Self, FPaintHelper);
end;

constructor TCustomBCEditor.TBuildRowsThread.Create(const AEditor: TCustomBCEditor);
begin
  inherited Create(False);

  FEditor := AEditor;

  FDC := CreateCompatibleDC(FEditor.Canvas.Handle);
  FPaintHelper := TPaintHelper.Create(FEditor.Font);
  FPaintHelper.BeginDraw(FDC);
end;

destructor TCustomBCEditor.TBuildRowsThread.Destroy();
begin
  FPaintHelper.EndDraw();
  FPaintHelper.Free();
  DeleteDC(FDC);

  inherited;
end;

function TCustomBCEditor.TBuildRowsThread.Terminated(): Boolean;
begin
  Result := inherited Terminated or (lsUpdating in FEditor.FLines.State);
end;

{ TCustomBCEditor.TOverlays ***************************************************}

function TCustomBCEditor.TOverlays.Add(const AValue: TOverlay): Integer;
var
  LIndex: Integer;
begin
  LIndex := 0;
  while ((LIndex < Count) and (Items[LIndex].Area.BeginPosition < AValue.Area.BeginPosition)) do
    Inc(LIndex);

  if ((AValue.Area.BeginPosition.Line <> AValue.Area.EndPosition.Line)
    or (AValue.Area.BeginPosition.Char < 0)
    or (AValue.Area.EndPosition.Char < AValue.Area.BeginPosition.Char)
    or (AValue.Area.EndPosition.Char > Length(FEditor.FLines.Items[AValue.Area.EndPosition.Line].Text))) then
    raise ERangeError.Create(SBCEditorOverlayInvalidArea);
  if ((LIndex > 0) and (Items[LIndex - 1].Area.EndPosition > AValue.Area.BeginPosition)) then
    raise ERangeError.Create(SBCEditorOverlayOverlap);

  Insert(LIndex, AValue);
  Result := LIndex;
end;

constructor TCustomBCEditor.TOverlays.Create(const AEditor: TCustomBCEditor);
begin
  inherited Create();

  FEditor := AEditor;
end;

{ TCustomBCEditor.TPaintHelper.TObjectFonts *******************************************}

function TCustomBCEditor.TPaintHelper.TObjectFonts.Add(const AStyle: TFontStyles): Integer;
const
  CBolds: array [Boolean] of Integer = (400, 700);
var
  LFont: TObjectFont;
  LIndex: Integer;
  LLogFont: TLogFont;
begin
  Result := -1;

  for LIndex := 0 to Count - 1 do
    if (Items[LIndex].Style = AStyle) then
      Result := LIndex;

  if (Result < 0) then
  begin
    GetObject(FFont.Handle, SizeOf(LLogFont), @LLogFont);
    LLogFont.lfWeight := CBolds[fsBold in AStyle];
    LLogFont.lfItalic := Ord(BOOL(fsItalic in AStyle));
    LLogFont.lfUnderline := Ord(BOOL(fsUnderline in AStyle));
    LLogFont.lfStrikeOut := Ord(BOOL(fsStrikeOut in AStyle));
    StrCopy(@LLogFont.lfFaceName[0], PChar(FFont.Name));
    LFont.Handle := CreateFontIndirect(LLogFont);
    LFont.Style := AStyle;
    Result := inherited Add(LFont);
  end;
end;

procedure TCustomBCEditor.TPaintHelper.TObjectFonts.Clear();
var
  LIndex: Integer;
begin
  for LIndex := 0 to Count - 1 do
    DeleteObject(Items[LIndex].Handle);

  inherited;
end;

constructor TCustomBCEditor.TPaintHelper.TObjectFonts.Create();
begin
  inherited;

  FFont := nil;
end;

destructor TCustomBCEditor.TPaintHelper.TObjectFonts.Destroy();
begin
  Clear();

  inherited;
end;

procedure TCustomBCEditor.TPaintHelper.TObjectFonts.SetFont(const AValue: TFont);
begin
  if (not Assigned(FFont)
    or (AValue.Name <> FFont.Name)
    or (AValue.Size <> FFont.Size)) then
  begin
    FFont := AValue;
    Clear();
  end;
end;

{ TCustomBCEditor.TPaintHelper ********************************************************}

procedure TCustomBCEditor.TPaintHelper.BeginDraw(const AHandle: HDC);
begin
  Assert(AHandle <> 0);

  FHandles.Push(FHandle);
  FSavedDCs.Push(SaveDC(FHandle));

  FHandle := AHandle;

  SelectObject(FHandle, FObjectFonts.Items[FObjectFonts.Add(FStyle)].Handle);
  SetTextColor(FHandle, ColorToRGB(FForegroundColor));
  SetBkColor(FHandle, ColorToRGB(FBackgroundColor));
  SetBkMode(FHandle, TRANSPARENT);
end;

constructor TCustomBCEditor.TPaintHelper.Create(const AFont: TFont);
begin
  inherited Create();

  FBackgroundColor := clWindow;
  FBrush := TBrush.Create();
  FForegroundColor := clWindowText;
  FHandle := 0;
  FHandles := TStack<HDC>.Create();
  FObjectFonts := TObjectFonts.Create();
  FSavedDCs := TStack<Integer>.Create();
  FStyle := [];
  SetFont(AFont);
end;

destructor TCustomBCEditor.TPaintHelper.Destroy();
begin
  Assert(FHandles.Count = 0);

  FBrush.Free();
  FHandles.Free();
  FObjectFonts.Free();
  FSavedDCs.Free();

  inherited;
end;

procedure TCustomBCEditor.TPaintHelper.EndDraw();
begin
  Assert(FHandles.Count > 0);

  FHandle := FHandles.Pop();
  RestoreDC(FHandle, FSavedDCs.Pop());
end;

function TCustomBCEditor.TPaintHelper.ExtTextOut(X, Y: Integer; Options: Longint;
  Rect: TRect; Str: LPCWSTR; Count: Longint; Dx: PInteger): BOOL;
begin
  Assert(FHandle <> 0);

  Result := Windows.ExtTextOut(FHandle, X, Y, Options, @Rect, Str, Count, Dx);
end;

function TCustomBCEditor.TPaintHelper.FillRect(const ARect: TRect): BOOL;
begin
  Assert(FHandle <> 0);

  Result := Windows.ExtTextOut(FHandle, 0, 0, ETO_OPAQUE, ARect, '', 0, nil);
end;

function TCustomBCEditor.TPaintHelper.FrameRect(const ARect: TRect; AColor: TColor): Integer;
begin
  FBrush.Color := AColor;
  Result := Windows.FrameRect(FHandle, ARect, FBrush.Handle);
end;

procedure TCustomBCEditor.TPaintHelper.SetBackgroundColor(const AValue: TColor);
begin
  if (AValue <> FBackgroundColor) then
  begin
    FBackgroundColor := AValue;
    if (FHandle <> 0) then
      SetBkColor(FHandle, ColorToRGB(FBackgroundColor));
  end;
end;

procedure TCustomBCEditor.TPaintHelper.SetFont(const AValue: TFont);
begin
  Assert(Assigned(AValue));

  FObjectFonts.Clear();

  ForegroundColor := AValue.Color;
  Style := AValue.Style;

  FObjectFonts.Font := AValue;
  SelectObject(FHandle, FObjectFonts.Items[FObjectFonts.Add(FStyle)].Handle);
end;

procedure TCustomBCEditor.TPaintHelper.SetForegroundColor(const AValue: TColor);
begin
  if (AValue <> FForegroundColor) then
  begin
    FForegroundColor := AValue;
    if (FHandle <> 0) then
      SetTextColor(FHandle, ColorToRGB(FForegroundColor));
  end;
end;

procedure TCustomBCEditor.TPaintHelper.SetStyle(const AValue: TFontStyles);
begin
  if (AValue <> FStyle) then
  begin
    FStyle := AValue;
    if (FHandle <> 0) then
      SelectObject(FHandle, FObjectFonts.Items[FObjectFonts.Add(FStyle)].Handle);
  end;
end;

function TCustomBCEditor.TPaintHelper.TextHeight(const AText: PChar; const ALength: Integer): Integer;
var
  LSize: TSize;
begin
  Assert(FHandle <> 0);

  if (not GetTextExtentPoint32(FHandle, AText, ALength, LSize)) then
    RaiseLastOSError();
  Result := LSize.cy;
end;

function TCustomBCEditor.TPaintHelper.TextWidth(const AText: PChar; const ALength: Integer): Integer;
var
  LSize: TSize;
begin
  Assert(FHandle <> 0);

  if (not GetTextExtentPoint32(FHandle, AText, ALength, LSize)) then
    RaiseLastOSError();
  Result := LSize.cx;
end;

{ TCustomBCEditor.TRows *******************************************************}

procedure TCustomBCEditor.TRows.Add(const AFlags: TRow.TFlags; const ALine: Integer;
  const AChar, ALength, AColumns, AWidth: Integer; const ABeginRange: Pointer;
  const AParts: TRow.TParts);
begin
  Insert(-1, AFlags, ALine, AChar, ALength, AColumns, AWidth, ABeginRange, AParts);
end;

procedure TCustomBCEditor.TRows.BeginBuild();
begin
  Assert(not Assigned(FCriticalSection));

  FCriticalSection := TCriticalSection.Create();
  Include(FState, rsBuilding);
end;

procedure TCustomBCEditor.TRows.Clear();
begin
  if (Assigned(FCriticalSection)) then FCriticalSection.Enter();

  inherited;

  FCaretPosition := InvalidRowsPosition;
  FMaxColumns := -1;
  FMaxColumnsRow := -1;
  FMaxWidth := -1;
  FMaxWidthRow := -1;

  if (Assigned(FCriticalSection)) then FCriticalSection.Leave();
end;

constructor TCustomBCEditor.TRows.Create(const AEditor: TCustomBCEditor);
begin
  inherited Create();

  FEditor := AEditor;

  FCriticalSection := nil;
  FMaxColumns := -1;
  FMaxColumnsRow := -1;
end;

procedure TCustomBCEditor.TRows.Delete(ARow: Integer);
begin
  if (Assigned(FCriticalSection)) then FCriticalSection.Enter();

  inherited;

  if (FMaxColumnsRow = ARow) then
  begin
    FMaxColumns := -1;
    FMaxColumnsRow := -1;
  end
  else if (FMaxColumnsRow > ARow) then
    Dec(FMaxColumnsRow);
  if (FMaxWidthRow = ARow) then
  begin
    FMaxWidth := -1;
    FMaxWidthRow := -1;
  end
  else if (FMaxWidthRow > ARow) then
    Dec(FMaxWidthRow);

  if (Assigned(FCriticalSection)) then FCriticalSection.Leave();
end;

destructor TCustomBCEditor.TRows.Destroy();
begin
  Clear(); // Clear is not virtual, so it must be called here

  if (Assigned(FCriticalSection)) then
    FCriticalSection.Free();

  inherited;
end;

procedure TCustomBCEditor.TRows.EndBuild();
begin
  Assert(Assigned(FCriticalSection));

  FCriticalSection.Free();
  FCriticalSection := nil;
  Exclude(FState, rsBuilding);
end;

function TCustomBCEditor.TRows.GetCaretPosition(): TBCEditorRowsPosition;
begin
  if (FCaretPosition = InvalidRowsPosition) then
    FCaretPosition := FEditor.LinesToRows(FEditor.FLines.CaretPosition);

  Result := FCaretPosition;
end;

function TCustomBCEditor.TRows.GetBORPosition(ARow: Integer): TBCEditorLinesPosition;
var
  LChar: Integer;
  LCount: Integer;
  LRow: Integer;
begin
  LCount := Count;
  if (ARow < LCount) then
  begin
    LChar := 0;
    LRow := FEditor.FLines.Items[Items[ARow].Line].FirstRow;
    while (LRow < ARow) do
    begin
      Inc(LChar, Items[LRow].Length);
      Inc(LRow);
    end;
    Result := LinesPosition(LChar, Items[ARow].Line);
  end
  else
    Result := FEditor.FLines.BOLPosition[(ARow - LCount) + FEditor.FLines.Count];
end;

function TCustomBCEditor.TRows.GetCount(): Integer;
begin
  if (Assigned(FCriticalSection)) then FCriticalSection.Enter();

  Result := inherited Count;

  if (Assigned(FCriticalSection)) then FCriticalSection.Leave();
end;

function TCustomBCEditor.TRows.GetEORPosition(ARow: Integer): TBCEditorLinesPosition;
begin
  Assert((0 <= ARow) and (ARow < Count));

  if (not (rfLastRowOfLine in Items[ARow].Flags)) then
    Result := LinesPosition(Items[ARow].Char + Items[ARow].Length - 1, Items[ARow].Line)
  else
    Result := FEditor.FLines.EOLPosition[Items[ARow].Line];
end;

function TCustomBCEditor.TRows.GetFmtText(): string;
var
  LCount: Integer;
  LRow: Integer;
  LStringBuilder: TStringBuilder;
begin
  LStringBuilder := TStringBuilder.Create();

  LCount := Count;
  for LRow := 0 to LCount - 1 do
  begin
    LStringBuilder.Append(FEditor.FLines.Items[Items[LRow].Line].Text, Items[LRow].Char, Items[LRow].Length);
    if (not (rfLastRowOfLine in Items[LRow].Flags)) then
      LStringBuilder.Append(#13#13#10)
    else if (LRow < LCount - 1) then
      LStringBuilder.Append(#13#10);
  end;

  Result := LStringBuilder.ToString();

  LStringBuilder.Free();
end;

function TCustomBCEditor.TRows.GetItem(AIndex: Integer): TRow;
begin
  if (Assigned(FCriticalSection)) then FCriticalSection.Enter();

  Result := inherited Items[AIndex];

  if (Assigned(FCriticalSection)) then FCriticalSection.Leave();
end;

function TCustomBCEditor.TRows.GetMaxColumns(): Integer;
var
  LCount: Integer;
  LRow: Integer;
begin
  if (Assigned(FCriticalSection)) then FCriticalSection.Enter();

  LCount := inherited Count;
  if ((FMaxColumns < 0) and (LCount > 0)) then
    for LRow := 0 to LCount - 1 do
      if (Items[LRow].Columns > FMaxColumns) then
      begin
        FMaxColumnsRow := LRow;
        FMaxColumns := Items[LRow].Columns;
      end;

  Result := FMaxColumns;

  if (Assigned(FCriticalSection)) then FCriticalSection.Leave();
end;

function TCustomBCEditor.TRows.GetMaxWidth(): Integer;
var
  LCount: Integer;
  LRow: Integer;
begin
  if (Assigned(FCriticalSection)) then FCriticalSection.Enter();

  LCount := inherited Count;
  if ((FMaxWidth < 0) and (LCount > 0)) then
    for LRow := 0 to LCount - 1 do
      if (Items[LRow].Width > FMaxWidth) then
      begin
        FMaxWidthRow := LRow;
        FMaxWidth := Items[LRow].Width;
      end;

  Result := FMaxWidth;

  if (Assigned(FCriticalSection)) then FCriticalSection.Leave();
end;

function TCustomBCEditor.TRows.GetRowArea(ARow: Integer): TBCEditorLinesArea;
begin
  Result.BeginPosition := BORPosition[ARow];
  Result.EndPosition := EORPosition[ARow];
end;

function TCustomBCEditor.TRows.GetText(ARow: Integer): string;
begin
  Assert((0 <= ARow) and (ARow < Count));

  Result := Copy(FEditor.FLines.Items[Items[ARow].Line].Text, 1 + Items[ARow].Char, Items[ARow].Length);
end;

procedure TCustomBCEditor.TRows.Insert(ARow: Integer; const AFlags: TRow.TFlags;
  const ALine: Integer; const AChar, ALength, AColumns, AWidth: Integer;
  const ABeginRange: Pointer; const AParts: TRow.TParts);
var
  LItem: TRow;
  LPos: PChar;
  LEndPos: PChar;
begin
  Assert((0 <= ARow) and (ARow <= Count));

  if (Assigned(FCriticalSection)) then FCriticalSection.Enter();

  LItem.BeginRange := ABeginRange;
  LItem.Char := AChar;
  LItem.Columns := AColumns;
  LItem.Flags := AFlags;
  LItem.Length := ALength;
  LItem.Line := ALine;
  LItem.Parts := AParts;
  LItem.Width := AWidth;

  if ((ALength > 0) and (lfContainsTabs in FEditor.FLines.Items[ALine].Flags)) then
  begin
    LPos := @FEditor.FLines.Items[ALine].Text[1 + AChar];
    LEndPos := @LPos[ALength - 1];
    while (LPos <= LEndPos) do
    begin
      if (LPos^ = BCEDITOR_TAB_CHAR) then
      begin
        Include(LItem.Flags, rfHasTabs);
        break;
      end;
      Inc(LPos);
    end;
  end;

  if (ARow < 0) then
    inherited Add(LItem)
  else
    inherited Insert(ARow, LItem);

  if ((FMaxColumns >= 0) and (AColumns > FMaxColumns)) then
  begin
    FMaxColumns := AColumns;
    FMaxColumnsRow := ARow;
  end
  else if (FMaxColumnsRow >= ARow) then
    Inc(FMaxColumnsRow);

  if ((FMaxWidth >= 0) and (AWidth > FMaxWidth)) then
  begin
    FMaxWidth := AWidth;
    FMaxWidthRow := ARow;
  end
  else if (FMaxWidthRow >= ARow) then
    Inc(FMaxWidthRow);

  if (Assigned(FCriticalSection)) then FCriticalSection.Leave();
end;

{ TCustomBCEditor *************************************************************}

procedure TCustomBCEditor.ActivateHint(const X, Y: Integer; const AHint: string);
var
  LRect: TRect;
begin
  if (not Assigned(FHintWindow)) then
  begin
    FHintWindow := THintWindow.Create(Self);
    FHintWindow.Color := clInfoBk;
  end;

  LRect := FHintWindow.CalcHintRect(FMetrics.ClientRect.Width, AHint, nil);
  LRect.Offset(X, Y);

  FHintWindow.ActivateHint(LRect, AHint);
end;

procedure TCustomBCEditor.AddHighlighterKeywords(AStringList: TStrings);
var
  LChar: Char;
  LIndex: Integer;
  LKeywordStringList: TStringList;
  LStringList: TStringList;
  LWord: string;
  LWordList: string;
begin
  LStringList := TStringList.Create;
  LKeywordStringList := TStringList.Create;
  LWordList := AStringList.Text;
  try
    FHighlighter.AddKeywords(LKeywordStringList);
    for LIndex := 0 to LKeywordStringList.Count - 1 do
    begin
      LWord := LKeywordStringList.Strings[LIndex];
      if Length(LWord) > 1 then
      begin
        LChar := LWord[1];
        if LChar.IsLower or LChar.IsUpper or (LChar = BCEDITOR_UNDERSCORE) then
          if Pos(LWord + BCEDITOR_CARRIAGE_RETURN + BCEDITOR_LINEFEED, LWordList) = 0 then { No duplicates }
            LWordList := LWordList + LWord + BCEDITOR_CARRIAGE_RETURN + BCEDITOR_LINEFEED;
      end;
    end;
    LStringList.Text := LWordList;
    LStringList.Sort;
    AStringList.Assign(LStringList);
  finally
    LKeywordStringList.Free;
    LStringList.Free;
  end;
end;

procedure TCustomBCEditor.AskReplaceText(ASender: TObject; const AArea: TBCEditorLinesArea;
  const ABackwards: Boolean; const AReplaceText: string; var AAction: TBCEditorReplaceAction);
begin
  Assert(ASender is TBCEditorLines.TSearch);

  Include(FState, esCenterCaret);
  try
    SetSelArea(AArea, ABackwards);
  finally
    Exclude(FState, esCenterCaret);
  end;

  if (Assigned(FOnReplacePrompt)) then
    FOnReplacePrompt(Self, AArea, ABackwards, AReplaceText, FReplaceAction)
  else
    case (MessageBox(WindowHandle, PChar(Format(SBCEditorReplaceTextPrompt, [AReplaceText])), PChar(SBCEditorMessageQuestion), MB_ICONQUESTION or MB_YESNOCANCEL)) of
      ID_YES:
        FReplaceAction := raReplace;
      ID_NO:
        FReplaceAction := raSkip;
      ID_CANCEL:
        FReplaceAction := raCancel;
    end;
end;

function TCustomBCEditor.AskSearchWrapAround(const AData: PBCEditorCommandDataFind): Boolean;
var
  LHandle: THandle;
  LText: string;
begin
  if (foWrapAround in AData^.Options) then
    Result := True
  else if (Assigned(FOnFindWrapAround)) then
    Result := FOnFindWrapAround(Self, AData^.Pattern, foBackwards in AData^.Options)
  else
  begin
    if (Assigned(FFindDialog)) then
      LHandle := FFindDialog.Handle
    else
      LHandle := WindowHandle;
    if (foBackwards in AData^.Options) then
      LText := Format(SBCEditorSearchWrapAroundBackwards, [AData^.Pattern])
    else
      LText := Format(SBCEditorSearchWrapAroundForwards, [AData^.Pattern]);
    Result := MessageBox(LHandle, PChar(LText), PChar(SBCEditorSearchWrapAroundTitle), MB_ICONQUESTION or MB_YESNO) = IDYES;
  end;
end;

procedure TCustomBCEditor.Assign(ASource: TPersistent);
begin
  if Assigned(ASource) and (ASource is TCustomBCEditor) then
    with ASource as TCustomBCEditor do
    begin
      Self.FCompletionProposal.Assign(FCompletionProposal);
      Self.FLeftMargin.Assign(FLeftMargin);
      Self.FTabs.Assign(FTabs);
    end
  else
    inherited Assign(ASource);
end;

procedure TCustomBCEditor.BeginUndoBlock();
begin
  FLines.BeginUpdate();
end;

procedure TCustomBCEditor.BeginUpdate();
begin
  if (FUpdateCount = 0) then SetUpdateState(True);
  Inc(FUpdateCount);
end;

procedure TCustomBCEditor.BookmarksChanged(ASender: TObject);
begin
  if (FLeftMargin.Marks.Visible) then
    InvalidateRect(FMetrics.MarksPanelRect);
end;

procedure TCustomBCEditor.BuildRows(const AThread: TBuildRowsThread;
  const APaintHelper: TPaintHelper);
const
  LRowToInsert = -2;
var
  LCodeFolding: Integer;
  LLastUpdateScrollBars: Integer;
  LLine: Integer;
  LRange: TBCEditorCodeFoldingRanges.TRange;
  LRow: Integer;
  LSynchronizeRowsWantedValid: Boolean;
  LTickCount: Integer;
begin
  FLines.BeginUpdate();
  try
    for LLine := 0 to FLines.Count - 1 do
      FLines.SetRow(LLine, LRowToInsert, 0);
    for LCodeFolding := 0 to FAllCodeFoldingRanges.AllCount - 1 do
    begin
      LRange := FAllCodeFoldingRanges[LCodeFolding];
      if (Assigned(LRange) and LRange.Collapsed) then
        for LLine := LRange.BeginLine + 1 to LRange.EndLine do
          FLines.SetRow(LLine, -1, 0);
    end;
  finally
    FLines.EndUpdate();
  end;

  LLastUpdateScrollBars := 0;
  LRow := FRows.Count;
  LLine := FLastLineInBuiltRows + 1;
  while ((LLine < FLines.Count) and not AThread.Terminated) do
  begin
    if (FLines.Items[LLine].FirstRow = LRowToInsert) then
    begin
      FLines.CriticalSection.Enter();
      Inc(LRow, InsertLineIntoRows(APaintHelper, AThread, LLine, LRow));
      FLines.CriticalSection.Leave();
    end
    else
      Inc(FLastLineInBuiltRows);

    FBuildRowsCriticalSection.Enter();
    try
      if (FBuildRowsThread.Terminated) then
        LSynchronizeRowsWantedValid := False
      else
        case (FRowsWanted.What) of
          rwPaintText:
            LSynchronizeRowsWantedValid := LRow > FRowsWanted.Row;
          rwScrollToPosition:
            LSynchronizeRowsWantedValid := LLine >= FRowsWanted.Position.Line;
          rwDown:
            LSynchronizeRowsWantedValid := LRow > FRowsWanted.Row;
          else
            LSynchronizeRowsWantedValid := False;
        end;
    finally
      FBuildRowsCriticalSection.Leave();
    end;
    if (LSynchronizeRowsWantedValid) then
      AThread.Synchronize(RowsWantedValid);

    LTickCount := GetTickCount();
    if (LTickCount >= LLastUpdateScrollBars + GClientRefreshTime) then
    begin
      LLastUpdateScrollBars := LTickCount;
      InvalidateScrollBars();
    end;

    Inc(LLine);
  end;

  FBuildRowsCriticalSection.Enter();
  try
    FRows.EndBuild();
    case (FRowsWanted.What) of
      rwPaintText:
        LSynchronizeRowsWantedValid := FRows.Count = 0;
      rwEOF:
        LSynchronizeRowsWantedValid := True;
      else
        LSynchronizeRowsWantedValid := False;
    end;
  finally
    FBuildRowsCriticalSection.Leave();
  end;
  if (LSynchronizeRowsWantedValid) then
    AThread.Synchronize(RowsWantedValid);

  InvalidateScrollBars();
end;

procedure TCustomBCEditor.CaretChanged(ASender: TObject);
begin
  InvalidateMatchingPair();
  InvalidateCaret();
  InvalidateSyncEditOverlays();

  if (esHighlightSearchAllAreas in FState) then
  begin
    Exclude(FState, esHighlightSearchAllAreas);
    InvalidateText();
  end;

  ScrollToPosition(FLines.CaretPosition);

  if (FUpdateCount > 0) then
    Include(FState, esCaretChanged)
  else
    if (Assigned(FOnCaretChanged)) then
      FOnCaretChanged(Self, CaretPos);
end;

procedure TCustomBCEditor.Change();
begin
  NotifyParent(EN_CHANGE);

  if (Assigned(FOnChange)) then
    FOnChange(Self);

  Include(FState, esTextUpdated);

  LinesChanged();
end;

procedure TCustomBCEditor.ChangeScale(M, D: Integer);
begin
  FCompletionProposal.ChangeScale(M, D);
end;

function TCustomBCEditor.CharAtCursor(): Char;
begin
  if (FLines.Count = 0) then
    Result := BCEDITOR_NONE_CHAR
  else
    Result := FLines.Char[FLines.CaretPosition];
end;

function TCustomBCEditor.CharIndexToPos(const ACharIndex: Integer): TPoint;
begin
  Result := FLines.PositionOf(ACharIndex);
end;

procedure TCustomBCEditor.Clear();
begin
  FLines.Clear();
end;

procedure TCustomBCEditor.ClearUndo();
begin
  FLines.ClearUndo();
end;

function TCustomBCEditor.ClientToLines(const X, Y: Integer; const AForCaret: Boolean = False): TBCEditorLinesPosition;
begin
  Result := RowsToLines(ClientToRows(X, Y, AForCaret));
end;

function TCustomBCEditor.ClientToRows(const X, Y: Integer; const AForCaret: Boolean = False): TBCEditorRowsPosition;
var
  LBeginRange: TBCEditorHighlighter.TRange;
  LChar: Integer;
  LColumn: Integer;
  LIndex: Integer;
  LLeft: Integer;
  LLength: Integer;
  LLine: Integer;
  LMiddle: Integer;
  LRight: Integer;
  LRow: Integer;
  LRowText: string;
  LText: PChar;
  LToken: TBCEditorHighlighter.TTokenFind;
  LTokenWidth: Integer;
  LWidths: array of Integer;
  LX: Integer;
begin
  LRow := Max(0, FTopRow + Y div LineHeight);

  if (X <= FMetrics.TextRect.Left) then
    Result := RowsPosition(0, LRow)
  else if (FRows.Count = 0) then
  begin
    LX := X - FMetrics.TextRect.Left + FTextPos.X;
    if (AForCaret) then
      Inc(LX, FSpaceWidth div 2);
    Result := RowsPosition(LX div FSpaceWidth, LRow - FRows.Count);
  end
  else if (LRow >= FRows.Count) then
  begin
    LX := X - FMetrics.TextRect.Left + FTextPos.X;
    if (AForCaret) then
      Inc(LX, FSpaceWidth div 2);
    Result := RowsPosition(LX div FSpaceWidth, LRow - FRows.Count + FLines.Count);
  end
  else if (X > FMetrics.TextRect.Right) then
    Result := RowsPosition(FRows.Items[LRow].Length, LRow)
  else
  begin
    LLine := FRows.Items[LRow].Line;
    LX := X - FMetrics.TextRect.Left + FTextPos.X;

    FPaintHelper.BeginDraw(Canvas.Handle);
    try
      LTokenWidth := 0;

      LLeft := FTextPos.X;
      if (GetFindTokenData(LRow, LLeft, LBeginRange, LText, LLength, LChar, LColumn)
        and FHighlighter.FindFirstToken(LBeginRange, LText, LLength, LChar, LToken)) then
      begin
        repeat
          LTokenWidth := TokenWidth(FPaintHelper, LLine, LToken.Text, LToken.Length, LColumn, @LToken);

          if (LX < LLeft + LTokenWidth) then
            break;

          Inc(LLeft, LTokenWidth);
          Inc(LColumn, TokenColumns(LToken.Text, LToken.Length, LColumn));
        until (not FHighlighter.FindNextToken(LToken));
        FHighlighter.FindClose(LToken);
      end;

      if (LX < LLeft + LTokenWidth) then
      begin
        SetLength(LWidths, LToken.Length + 1);
        for LIndex := 1 to Length(LWidths) - 2 do
          LWidths[LIndex] := -1;
        LWidths[0] := LLeft;
        LWidths[Length(LWidths) - 1] := LLeft + LTokenWidth;

        LLeft := 0;
        LRight := Length(LWidths) - 1;
        while (LRight - LLeft >= 2) do
        begin
          LMiddle := (LLeft + LRight) div 2;

          if (LWidths[LMiddle] < 0) then
            LWidths[LMiddle] := LLeft + TokenWidth(FPaintHelper, LLine, LToken.Text, LMiddle, LColumn, @LToken);

          case (Sign(LWidths[LMiddle] - LX)) of
            -1: LLeft := LMiddle;
            0:
              begin
                Result := RowsPosition(LColumn + LMiddle, LRow);
                LRowText := FRows[LRow];
                while (Result.Column < Length(LRowText) - 1)
                  and ((LRowText[1 + Result.Column + 1].GetUnicodeCategory in [TUnicodeCategory.ucCombiningMark, TUnicodeCategory.ucNonSpacingMark])
                    or (LRowText[1 + Result.Column].GetUnicodeCategory = TUnicodeCategory.ucNonSpacingMark)
                      and not IsCombiningDiacriticalMark(LRowText[1 + Result.Column])) do
                  Inc(Result.Column);
                Exit(Result);
              end;
            1: LRight := LMiddle;
          end;
        end;

        if (LWidths[LLeft] < 0) then
          LWidths[LLeft] := LLeft + TokenWidth(FPaintHelper, LLine, LToken.Text, LLeft, LColumn, @LToken);
        if (LWidths[LRight] < 0) then
          LWidths[LRight] := LLeft + TokenWidth(FPaintHelper, LLine, LToken.Text, LRight, LColumn, @LToken);

        if ((LX - LWidths[LLeft]) < (LWidths[LRight] - LX)) then
          Result := RowsPosition(LColumn + LLeft, LRow)
        else
          Result := RowsPosition(LColumn + LRight, LRow);

        if (LRow < FRows.Count) then
        begin
          LRowText := FRows[LRow];
          while (Result.Column < LRowText.Length - 1)
            and ((LRowText[1 + Result.Column + 1].GetUnicodeCategory in [TUnicodeCategory.ucCombiningMark, TUnicodeCategory.ucNonSpacingMark])
              or (LRowText[1 + Result.Column].GetUnicodeCategory = TUnicodeCategory.ucNonSpacingMark)
                and not IsCombiningDiacriticalMark(LRowText[1 + Result.Column])) do
            Inc(Result.Column);
        end;
      end
      else if (not AForCaret) then
        Result := RowsPosition(LColumn + (LX - LLeft) div FSpaceWidth, LRow)
      else
        Result := RowsPosition(LColumn + (LX - LLeft + FSpaceWidth div 2) div FSpaceWidth, LRow)
    finally
      FPaintHelper.EndDraw();
    end;
  end;
end;

function TCustomBCEditor.ClientToPos(const X, Y: Integer): TPoint;
begin
  Result := ClientToLines(X, Y);
end;

function TCustomBCEditor.ClientToText(const X, Y: Integer): TPoint;
begin
  Result := ClientToPos(X, Y);
end;

procedure TCustomBCEditor.CMDoubleBufferedChanged(var AMessage: TMessage);
begin
  if (Assigned(FDoubleBufferBitmap)) then
    FreeAndNil(FDoubleBufferBitmap);
  if (Assigned(FDoubleBufferOverlayBitmap)) then
    FreeAndNil(FDoubleBufferOverlayBitmap);

  if (not DoubleBuffered) then
    Exclude(FState, esDoubleBufferInvalid)
  else
  begin
    if (Canvas.HandleAllocated) then
    begin
      FDoubleBufferBitmap := TBitmap.Create();
      FDoubleBufferBitmap.Handle := CreateCompatibleBitmap(Canvas.Handle, FMetrics.ClientRect.Width, FMetrics.ClientRect.Height);
      FDoubleBufferOverlayBitmap := TBitmap.Create();
      FDoubleBufferOverlayBitmap.Handle := CreateCompatibleBitmap(Canvas.Handle, FMetrics.ClientRect.Width, FMetrics.ClientRect.Height);
    end;
    FDoubleBufferUpdateRect := Rect(-1, -1, -1, -1);
    Include(FState, esDoubleBufferInvalid);
  end;
end;

procedure TCustomBCEditor.CMSysFontChanged(var AMessage: TMessage);
begin
  if (Assigned(FHintWindow)) then
    FreeAndNil(FHintWindow);

  FMarksPanelWidth := GetSystemMetrics(SM_CXSMICON) + GetSystemMetrics(SM_CXSMICON) div 4;
  FLineStateWidth := GetSystemMetrics(SM_CXSMICON) div 4;
  FLeftMarginBorderWidth := 2 * GLineWidth;
  UpdateMetrics();

  FState := FState + [esSysFontChanged];

  inherited;
end;

function TCustomBCEditor.CodeFoldingCollapsableFoldRangeForLine(const ALine: Integer): TBCEditorCodeFoldingRanges.TRange;
var
  LRange: TBCEditorCodeFoldingRanges.TRange;
begin
  LRange := TBCEditorCodeFoldingRanges.TRange(FLines.Items[ALine].CodeFolding.BeginRange);
  if (not Assigned(LRange) or not LRange.Collapsable()) then
    Result := nil
  else
    Result := LRange;
end;

function TCustomBCEditor.CodeFoldingFoldRangeForLineTo(const ALine: Integer): TBCEditorCodeFoldingRanges.TRange;
var
  LRange: TBCEditorCodeFoldingRanges.TRange;
begin
  Result := nil;

  LRange := FLines.Items[ALine].CodeFolding.EndRange;
  if Assigned(LRange) then
    if (LRange.EndLine = ALine) and not LRange.ParentCollapsed then
      Result := LRange;
end;

procedure TCustomBCEditor.CollapseCodeFoldingLevel(const AFirstLevel: Integer; const ALastLevel: Integer);
var
  LFirstLine: Integer;
  LLastLine: Integer;
  LLevel: Integer;
  LLine: Integer;
  LRange: TBCEditorCodeFoldingRanges.TRange;
  LRangeLevel: Integer;
begin
  if (not FLines.SelArea.IsEmpty()) then
  begin
    LFirstLine := FLines.SelArea.BeginPosition.Line;
    LLastLine := FLines.SelArea.EndPosition.Line;
  end
  else
  begin
    LFirstLine := FLines.BOFPosition.Line;
    LLastLine := FLines.EOFPosition.Line;
  end;

  BeginUpdate();

  LLevel := -1;
  for LLine := LFirstLine to LLastLine do
  begin
    LRange := TBCEditorCodeFoldingRanges.TRange(FLines.Items[LLine].CodeFolding.BeginRange);
    if (Assigned(LRange)) then
    begin
      if (LLevel = -1) then
        LLevel := LRange.FoldRangeLevel;
      LRangeLevel := LRange.FoldRangeLevel - LLevel;
      if ((AFirstLevel <= LRangeLevel) and (LRangeLevel <= ALastLevel)
        and not LRange.Collapsed and LRange.Collapsable) then
        CollapseCodeFoldingRange(LRange);
    end;
  end;

  EndUpdate();
end;

function TCustomBCEditor.CollapseCodeFoldingLines(const AFirstLine: Integer = -1; const ALastLine: Integer = -1): Integer;
var
  LFirstLine: Integer;
  LLastLine: Integer;
  LLine: Integer;
  LRange: TBCEditorCodeFoldingRanges.TRange;
begin
  if (AFirstLine >= 0) then
    LFirstLine := AFirstLine
  else
    LFirstLine := 0;
  if (ALastLine >= 0) then
    LLastLine := ALastLine
  else if (AFirstLine >= 0) then
    LLastLine := AFirstLine
  else
    LLastLine := FLines.Count - 1;

  BeginUpdate();

  Result := 0;
  for LLine := LFirstLine to LLastLine do
  begin
    LRange := TBCEditorCodeFoldingRanges.TRange(FLines.Items[LLine].CodeFolding.BeginRange);
    if (Assigned(LRange) and not LRange.Collapsed and LRange.Collapsable) then
    begin
      CollapseCodeFoldingRange(LRange);
      Inc(Result);
    end;
  end;

  EndUpdate();
end;

procedure TCustomBCEditor.CollapseCodeFoldingRange(const ARange: TBCEditorCodeFoldingRanges.TRange);
var
  LLine: Integer;
begin
  if (not ARange.Collapsed) then
  begin
    ARange.Collapsed := True;
    ARange.SetParentCollapsedOfSubCodeFoldingRanges(True, ARange.FoldRangeLevel);

    for LLine := ARange.BeginLine + 1 to ARange.EndLine do
      DeleteLineFromRows(LLine);

    if ((ARange.BeginLine + 1 <= FLines.CaretPosition.Line) and (FLines.CaretPosition.Line <= ARange.EndLine)) then
      FLines.CaretPosition := FLines.BOLPosition[ARange.BeginLine];

    InvalidateText(True);
    InvalidateScrollBars();
  end;
end;

procedure TCustomBCEditor.ColorsChanged(ASender: TObject);
begin
  InvalidateClient();
end;

procedure TCustomBCEditor.CommandProcessor(ACommand: TBCEditorCommand; AChar: Char; AData: Pointer);
begin
end;

procedure TCustomBCEditor.CopyToClipboard();
begin
  ProcessCommand(ecCopyToClipboard);
end;

constructor TCustomBCEditor.Create(AOwner: TComponent);
var
  LIndex: Integer;
  LLogFont: TLogFont;
  LNonClientMetrics: TNonClientMetrics;
begin
  inherited;

  Color := clWindow;
  ControlStyle := ControlStyle + [csOpaque, csNeedsBorderPaint];
  DoubleBuffered := True;
  Height := 89;
  ParentColor := False;
  TabStop := True;
  Width := 185;

  for LIndex := 0 to Length(FBookmarkBitmaps) - 1 do
    FBookmarkBitmaps[LIndex] := nil;
  FBorderStyle := bsSingle;
  FBuildRowsCriticalSection := TCriticalSection.Create();
  FCaretVisible := False;
  FCaretWidth := 0;
  FCursorPoint := Point(-1, -1);
  FCodeFoldingCollapsedBitmap := nil;
  FCodeFoldingExpandedBitmap := nil;
  FCodeFoldingLineBitmap := nil;
  FCodeFoldingEndLineBitmap := nil;
  FDefaultFontSize := Font.Size + 1;
  FDoubleBufferBitmap := nil;
  FDoubleClickTime := GetDoubleClickTime();
  FFmtLines := False;
  FGotoLineDialog := nil;
  FHideScrollBars := True;
  FHideSelection := True;
  FHintWindow := nil;
  FHookedCommandHandlers := TBCEditorHookedCommandHandlers.Create(Self);
  FIMEStatus := 0;
  FInsertPos := InvalidPos;
  FInsertPosBitmap := nil;
  FInsertPosCache := nil;
  FMouseCapture := mcNone;
  FNoParentNotify := False;
  FLastCursorPoint := Point(-1, -1);
  FLastLineInBuiltRows := -1;
  FLastSearch := lsFind;
  FLastSearchData := nil;
  FLineHeight := 0;
  FOldClientRect := Rect(-1, -1, -1, -1);
  FOldActiveLine := -1;
  FOldSelArea := InvalidLinesArea;
  FOnChange := nil;
  FOnCompletionProposalClose := nil;
  FOnCompletionProposalShow := nil;
  FOnFindExecuted := nil;
  FOnFindWrapAround := nil;
  FOptions := DefaultOptions;
  FParentWnd := 0;
  FPopupMenu := 0;
  FReadOnly := False;
  FReplaceAction := raReplace;
  FScrollBars := ssBoth;
  FScrollingBitmap := nil;
  FFindDialog := nil;
  FReplaceDialog := nil;
  FRowsWanted.What := rwNothing;
  FSelectedCaseText := '';
  FSelectionOptions := DefaultSelectionOptions;
  FState := [];
  FSyncEditButtonHotBitmap := nil;
  FSyncEditButtonNormalBitmap := nil;
  FSyncEditButtonPressedBitmap := nil;
  FSyncEditOptions := DefaultSyncEditOptions;
  FTextEntryMode := temInsert;
  FTopRow := 0;
  FUCCVisible := False;
  FUsableRows := 0;
  FUpdateCount := 0;
  FVisibleRows := 0;
  FWantTabs := True;
  FWantReturns := True;
  FWordWrap := False;

  { Colors }
  FColors := TBCEditorColors.Create();
  FColors.OnChange := ColorsChanged;
  { Code folding }
  FAllCodeFoldingRanges := TBCEditorCodeFoldingAllRanges.Create;
  { Text buffer }
  FLines := TBCEditorLines(CreateLines());
  FLines.AfterUpdate := LinesAfterUpdate;
  FLines.BeforeUpdate := LinesBeforeUpdate;
  FLines.OnBookmarksChange := BookmarksChanged;
  FLines.OnCaretChange := CaretChanged;
  FLines.OnClear := LinesCleared;
  FLines.OnDelete := LineDeleting;
  FLines.OnInsert := LineInserted;
  FLines.OnLoad := LinesLoaded;
  FLines.OnMarksChange := MarksChanged;
  FLines.OnReplacePrompt := AskReplaceText;
  FLines.OnSelChange := LinesSelChanged;
  FLines.OnSyncEditChange := LinesSyncEditChanged;
  FLines.OnUpdate := LineUpdated;
  FRows := TCustomBCEditor.TRows.Create(Self);
  { Font }
  LNonClientMetrics.cbSize := SizeOf(LNonClientMetrics);
  if (SystemParametersInfo(SPI_GETNONCLIENTMETRICS, SizeOf(LNonClientMetrics), @LNonClientMetrics, 0)
    and (GetObject(Font.Handle, SizeOf(LLogFont), @LLogFont) <> 0)) then
  begin
    LLogFont.lfQuality := LNonClientMetrics.lfMessageFont.lfQuality;
    Font.Handle := CreateFontIndirect(LLogFont);
  end;
  Font.Name := DefaultFontName;
  Font.Size := FDefaultFontSize;
  Font.OnChange := FontChanged;
  { Painting }
  FPaintHelper := TCustomBCEditor.TPaintHelper.Create(Font);
  FOverlays := TOverlays.Create(Self);
  { Tabs }
  FTabs := TBCEditorTabs.Create;
  FTabs.OnChange := TabsChanged;
  { Completion proposal }
  FCompletionProposal := TBCEditorCompletionProposal.Create(Self);
  { FLeftMargin }
  FLeftMargin := TBCEditorLeftMargin.Create(Self);
  FLeftMargin.OnChange := LeftMarginChanged;
  { Do update character constraints }
  TabsChanged(nil);
  { Highlighter }
  FHighlighter := TBCEditorHighlighter.Create(Self);
  FHighlighter.OnChange := HighlighterChanged;

  if (not SystemParametersInfo(SPI_GETWHEELSCROLLCHARS, 0, @FWheelScrollChars, 0)) then
    FWheelScrollChars := 3;
end;

function TCustomBCEditor.CreateLines(): BCEditor.Lines.TBCEditorLines;
begin
  Result := BCEditor.Lines.TBCEditorLines.Create();
end;

procedure TCustomBCEditor.CreateParams(var AParams: TCreateParams);
const
  LBorderStyles: array [TBorderStyle] of DWORD = (0, WS_BORDER);
begin
  inherited;

  with AParams do
  begin
    WindowClass.Style := WindowClass.Style and not CS_VREDRAW and not CS_HREDRAW;
    Style := Style or LBorderStyles[FBorderStyle] or WS_CLIPCHILDREN or ES_AUTOHSCROLL or ES_AUTOVSCROLL;
    if (FReadOnly) then
      Style := Style or ES_READONLY;
    if (eoDropFiles in FOptions) then
      ExStyle := ExStyle or WS_EX_ACCEPTFILES;

    if (NewStyleControls and Ctl3D and (FBorderStyle = bsSingle)) then
    begin
      Style := Style and not WS_BORDER;
      ExStyle := ExStyle or WS_EX_CLIENTEDGE;
    end;
  end;
end;

procedure TCustomBCEditor.CreateWnd();
begin
  inherited;

  if (not Assigned(Parent)) then
  begin
    FFormWnd := 0;
    FParentWnd := 0;
  end
  else
  begin
    FFormWnd := GetParentForm(Self).Handle;
    FParentWnd := Parent.Handle;
  end;
  FDlgCtrlID := GetDlgCtrlID(WindowHandle);
  FNoParentNotify := GetWindowLong(WindowHandle, GWL_EXSTYLE) and WS_EX_NOPARENTNOTIFY <> 0;

  OleCheck(RegisterDragDrop(WindowHandle, Self));

  FState := FState + [esFontChanged, esSizeChanged, esScrollBarsInvalid];
end;

function TCustomBCEditor.DeleteBookmark(const ALine: Integer; const AIndex: Integer): Boolean;
var
  LBookmark: TBCEditorLines.TMark;
  LIndex: Integer;
begin
  Result := False;
  LIndex := 0;
  while LIndex < FLines.Bookmarks.Count do
  begin
    LBookmark := FLines.Bookmarks.Items[LIndex];
    if LBookmark.Pos.Y = ALine then
    begin
      if LBookmark.Index = AIndex then
        Result := True;
      FLines.Bookmarks.Delete(LIndex);
    end
    else
      Inc(LIndex);
  end;
end;

procedure TCustomBCEditor.CutToClipboard();
begin
  ProcessCommand(ecCutToClipboard);
end;

procedure TCustomBCEditor.DeleteChar();
begin
  if (not FLines.SelArea.IsEmpty()) then
    FLines.DeleteText(FLines.SelArea)
  else if ((FLines.CaretPosition.Line < FLines.Count)
    and (FLines.CaretPosition.Char < Length(FLines.Items[FLines.CaretPosition.Line].Text))) then
    FLines.DeleteText(LinesArea(FLines.CaretPosition, LinesPosition(FLines.CaretPosition.Char + 1, FLines.CaretPosition.Line)))
  else if (FLines.CaretPosition.Line < FLines.Count - 1) then
    FLines.DeleteText(LinesArea(FLines.CaretPosition, FLines.BOLPosition[FLines.CaretPosition.Line + 1]));
end;

procedure TCustomBCEditor.DeleteLastWordOrBOL(const ACommand: TBCEditorCommand);
var
  LNewCaretPosition: TBCEditorLinesPosition;
begin
  if (ACommand = ecDeleteLastWord) then
    LNewCaretPosition := PreviousWordPosition(FLines.CaretPosition)
  else
    LNewCaretPosition := FLines.BOLPosition[FLines.CaretPosition.Line];
  if (LNewCaretPosition <> FLines.CaretPosition) then
    if (FLines.CaretPosition.Line < FLines.Count) then
      FLines.DeleteText(LinesArea(LNewCaretPosition, Min(FLines.CaretPosition, FLines.EOLPosition[FLines.CaretPosition.Line])))
    else
      FLines.CaretPosition := LNewCaretPosition;
end;

procedure TCustomBCEditor.DeleteLine();
begin
  if (not FLines.SelArea.IsEmpty()) then
    FLines.SelArea := LinesArea(FLines.CaretPosition, FLines.CaretPosition)
  else if (FLines.CaretPosition.Line < FLines.Count) then
    FLines.Delete(FLines.CaretPosition.Line);
end;

procedure TCustomBCEditor.DeleteLineFromRows(const ALine: Integer);
var
  LDeletedRows: Integer;
  LLastRow: Integer;
  LLine: Integer;
  LRow: Integer;
begin
  if ((FRows.Count > 0)
    and (FLines.Items[ALine].FirstRow >= 0)) then
  begin
    LLastRow := FLines.Items[ALine].FirstRow;
    while (not (rfLastRowOfLine in FRows.Items[LLastRow].Flags)) do
      Inc(LLastRow);

    LDeletedRows := LLastRow - FLines.Items[ALine].FirstRow + 1;

    if (FLines.CaretPosition.Line = ALine) then
      if (ALine = 0) then
        FLines.CaretPosition := FLines.BOFPosition
      else
        FLines.CaretPosition := FLines.BOLPosition[ALine - 1]
    else if ((FLines.CaretPosition.Line > ALine)
      and not (esCaretInvalid in FState)) then
    begin
      Dec(FCaretPos.Y, LDeletedRows * FLineHeight);
      UpdateCaret();
    end;

    for LRow := LLastRow downto FLines.Items[ALine].FirstRow do
      FRows.Delete(LRow);

    FLines.SetRow(ALine, -1, 0);
    for LLine := ALine + 1 to FLines.Count - 1 do
      FLines.SetRow(LLine, FLines.Items[LLine].FirstRow - LDeletedRows, FLines.Items[LLine].RowCount);

    Dec(FLastLineInBuiltRows);
  end;
end;

destructor TCustomBCEditor.Destroy();
var
  LHandled: Boolean;
begin
  LHandled := False;
  FHookedCommandHandlers.Broadcast(True, ecTerminate, nil, LHandled);

  if (Assigned(FBuildRowsThread)) then
  begin
    FBuildRowsThread.Terminate();
    FBuildRowsThread.WaitFor();
    FBuildRowsThread.Free();
    FBuildRowsThread := nil;
  end;

  FLines.TerminateJob(True);

  FAllCodeFoldingRanges.Free();
  FCompletionProposal.Free();
  if Assigned(FCompletionProposalPopup) then
    FCompletionProposalPopup.Free();
  FColors.Free();
  if (Assigned(FDoubleBufferBitmap)) then
    FreeAndNil(FDoubleBufferBitmap);
  if (Assigned(FDoubleBufferOverlayBitmap)) then
    FreeAndNil(FDoubleBufferOverlayBitmap);
  FHighlighter.Free();
  if (Assigned(FHintWindow)) then
    FHintWindow.Free();
  FHookedCommandHandlers.Free();
  if (Assigned(FInsertPosCache)) then
    FInsertPosCache.Free();
  if (Assigned(FInsertPosBitmap)) then
    FInsertPosBitmap.Free();
  FLeftMargin.Free();
  FLines.Free();
  FOverlays.Free();
  FPaintHelper.Free();
  FRows.Free();
  FBuildRowsCriticalSection.Free();
  if (Assigned(FScrollingBitmap)) then
    FScrollingBitmap.Free();
  if (Assigned(FSyncEditButtonHotBitmap)) then
    FSyncEditButtonHotBitmap.Free();
  if (Assigned(FSyncEditButtonNormalBitmap)) then
    FSyncEditButtonNormalBitmap.Free();
  if (Assigned(FSyncEditButtonPressedBitmap)) then
    FSyncEditButtonPressedBitmap.Free();
  FTabs.Free();

  inherited;
end;

procedure TCustomBCEditor.DestroyWnd();
begin
  RevokeDragDrop(WindowHandle);

  FParentWnd := 0;

  inherited;
end;

procedure TCustomBCEditor.DoBackspace();
var
  LBackCounterLine: Integer;
  LLength: Integer;
  LNewCaretPosition: TBCEditorLinesPosition;
  LRange: TBCEditorCodeFoldingRanges.TRange;
  LSpaceCount1: Integer;
  LSpaceCount2: Integer;
  LVisualSpaceCount1: Integer;
  LVisualSpaceCount2: Integer;
begin
  FLines.BeginUpdate();
  try
    if (not FLines.SelArea.IsEmpty()) then
      SelText := ''
    else if (FLines.CaretPosition > FLines.BOFPosition) then
    begin
      if ((FLines.CaretPosition.Line < FLines.Count)
        and (FLines.CaretPosition.Char > Length(FLines.Items[FLines.CaretPosition.Line].Text))) then
      begin
        if (Length(FLines.Items[FLines.CaretPosition.Line].Text) > 0) then
          FLines.CaretPosition := FLines.EOLPosition[FLines.CaretPosition.Line]
        else
        begin
          LSpaceCount1 := FLines.CaretPosition.Char;
          LSpaceCount2 := 0;
          if LSpaceCount1 > 0 then
          begin
            LBackCounterLine := FLines.CaretPosition.Line;
            while LBackCounterLine >= 0 do
            begin
              LSpaceCount2 := LeftSpaceCount(FLines.Items[LBackCounterLine].Text);
              if LSpaceCount2 < LSpaceCount1 then
                Break;
              Dec(LBackCounterLine);
            end;
            if (LBackCounterLine = -1) and (LSpaceCount2 > LSpaceCount1) then
              LSpaceCount2 := 0;
          end;
          if LSpaceCount2 = LSpaceCount1 then
            LSpaceCount2 := 0;

          FLines.CaretPosition := LinesPosition(FLines.CaretPosition.Char - (LSpaceCount1 - LSpaceCount2), FLines.CaretPosition.Line);
        end;
      end
      else if ((FLines.CaretPosition.Line < FLines.Count)
        and (FLines.CaretPosition.Char > 0)) then
      begin
        LSpaceCount1 := LeftSpaceCount(FLines.Items[FLines.CaretPosition.Line].Text);
        LSpaceCount2 := 0;
        if ((FLines.CaretPosition.Char < Length(FLines.Items[FLines.CaretPosition.Line].Text) - 1)
          and (FLines.Char[FLines.CaretPosition] = BCEDITOR_SPACE_CHAR)
            or (LSpaceCount1 <> FLines.CaretPosition.Char)) then
        begin
          LNewCaretPosition := LinesPosition(FLines.CaretPosition.Char - 1, FLines.CaretPosition.Line);
          if (FLines.Char[LNewCaretPosition].IsSurrogate()) then
            Dec(LNewCaretPosition.Char);
        end
        else
        begin
          LVisualSpaceCount1 := GetLeadingExpandedLength(FLines.Items[FLines.CaretPosition.Line].Text);
          LVisualSpaceCount2 := 0;
          LBackCounterLine := FLines.CaretPosition.Line - 1;
          while LBackCounterLine >= 0 do
          begin
            LVisualSpaceCount2 := GetLeadingExpandedLength(FLines.Items[LBackCounterLine].Text);
            if LVisualSpaceCount2 < LVisualSpaceCount1 then
            begin
              LSpaceCount2 := LeftSpaceCount(FLines.Items[LBackCounterLine].Text);
              Break;
            end;
            Dec(LBackCounterLine);
          end;

          if ((LSpaceCount2 > 0)
            and ((LBackCounterLine >= 0) or (LSpaceCount2 <= LSpaceCount1))
            and (LSpaceCount2 <> LSpaceCount1)) then
          begin
            LNewCaretPosition := FLines.CaretPosition;

            LLength := GetLeadingExpandedLength(FLines.Items[FLines.CaretPosition.Line].Text, LNewCaretPosition.Char);
            while ((LNewCaretPosition.Char > 0) and (LLength > LVisualSpaceCount2)) do
            begin
              Dec(LNewCaretPosition.Char);
              LLength := GetLeadingExpandedLength(FLines.Items[FLines.CaretPosition.Line].Text, LNewCaretPosition.Char);
            end;
          end
          else
          begin
            LNewCaretPosition := LinesPosition(FLines.CaretPosition.Char - 1, FLines.CaretPosition.Line);
            LVisualSpaceCount2 := LVisualSpaceCount1 - (LVisualSpaceCount1 mod FTabs.Width);
            if (LVisualSpaceCount2 = LVisualSpaceCount1) then
              LVisualSpaceCount2 := Max(LVisualSpaceCount2 - FTabs.Width, 0);

            LLength := GetLeadingExpandedLength(FLines.Items[FLines.CaretPosition.Line].Text, LNewCaretPosition.Char - 1);
            while (LNewCaretPosition.Char > 0) and (LLength > LVisualSpaceCount2) do
            begin
              Dec(LNewCaretPosition.Char);
              LLength := GetLeadingExpandedLength(FLines.Items[FLines.CaretPosition.Line].Text, LNewCaretPosition.Char);
            end;
          end;
        end;

        FLines.DeleteText(LinesArea(LNewCaretPosition, FLines.CaretPosition), True);
      end
      else if (FLines.CaretPosition.Line >= FLines.Count) then
        if (FLines.CaretPosition.Char > 0) then
          FLines.CaretPosition := LinesPosition(0, FLines.CaretPosition.Line)
        else if (FLines.CaretPosition.Line = FLines.Count) then
          FLines.CaretPosition := FLines.EOLPosition[FLines.CaretPosition.Line - 1]
        else
          FLines.CaretPosition := LinesPosition(0, FLines.CaretPosition.Line - 1)
      else if (FLines.CaretPosition.Line > 0) then
      begin
        LNewCaretPosition := FLines.EOLPosition[FLines.CaretPosition.Line - 1];

        LRange := CodeFoldingFoldRangeForLineTo(LNewCaretPosition.Line);
        if (Assigned(LRange) and LRange.Collapsed) then
        begin
          LNewCaretPosition.Line := LRange.BeginLine;
          Inc(LNewCaretPosition.Char, Length(FLines.Items[LNewCaretPosition.Line].Text) + 1);
        end;

        FLines.DeleteText(LinesArea(LNewCaretPosition, FLines.CaretPosition), True);
      end
      else
        FLines.CaretPosition := FLines.BOFPosition;
    end;
  finally
    FLines.EndUpdate();
  end;
end;

procedure TCustomBCEditor.DoBlockComment();
var
  LArea: TBCEditorLinesArea;
  LCommentIndex: Integer;
  LCommentLength: Integer;
  LIndentText: string;
  LIndex: Integer;
  LLinesDeleted: Integer;
  LText: string;
begin
  LCommentLength := Length(FHighlighter.Comments.BlockComments);

  if (LCommentLength = 0) then
    // No BlockComment defined in the Highlighter
  else
  begin
    LArea := FLines.SelArea;

    if (LArea.EndPosition <> FLines.BOFPosition) then
    begin
      LText := Trim(FLines.TextIn[LArea]);

      LCommentIndex := -2;
      LIndex := 0;
      while (LIndex + 1 < LCommentLength) do
        if ((Length(LText) >= Length(FHighlighter.Comments.BlockComments[LIndex]) + Length(FHighlighter.Comments.BlockComments[LIndex + 1]))
          and (LeftStr(LText, Length(FHighlighter.Comments.BlockComments[LIndex])) = FHighlighter.Comments.BlockComments[LIndex])
          and (RightStr(LText, Length(FHighlighter.Comments.BlockComments[LIndex + 1])) = FHighlighter.Comments.BlockComments[LIndex + 1])) then
        begin
          LCommentIndex := LIndex;
          break;
        end
        else
          Inc(LIndex, 2);

      if (LCommentIndex < 0) then
      begin
        LArea.BeginPosition.Char := 0;
        if (LArea.EndPosition.Line < FLines.Count - 1) then
          LArea.EndPosition := FLines.BOLPosition[LArea.EndPosition.Line]
        else
          LArea.EndPosition := FLines.EOLPosition[LArea.EndPosition.Line];

        LText := Trim(FLines.TextIn[LArea]);

        LCommentIndex := -2;
        LIndex := 0;
        while (LIndex + 1 < LCommentLength) do
          if ((Length(LText) >= Length(FHighlighter.Comments.BlockComments[LIndex]) + Length(FHighlighter.Comments.BlockComments[LIndex + 1]))
            and (LeftStr(LText, Length(FHighlighter.Comments.BlockComments[LIndex])) = FHighlighter.Comments.BlockComments[LIndex])
            and (RightStr(LText, Length(FHighlighter.Comments.BlockComments[LIndex + 1])) = FHighlighter.Comments.BlockComments[LIndex + 1])) then
          begin
            LCommentIndex := LIndex;
            break;
          end
          else
            Inc(LIndex, 2);
      end;


      FLines.BeginUpdate();
      try
        if (LCommentIndex >= 0) then
        begin
          LText := FLines.TextIn[LArea];

          LArea.BeginPosition := FLines.PositionOf(LeftTrimLength(LText), LArea.BeginPosition);
          LArea.EndPosition := FLines.PositionOf(Length(Trim(LText)), LArea.BeginPosition);

          LLinesDeleted := 0;
          FLines.DeleteText(LinesArea(LArea.BeginPosition, LinesPosition(LArea.BeginPosition.Char + Length(FHighlighter.Comments.BlockComments[LIndex]), LArea.BeginPosition.Line)));
          if (Trim(FLines.Items[LArea.BeginPosition.Line].Text) = '') then
          begin
            FLines.Delete(LArea.BeginPosition.Line);
            Dec(LArea.EndPosition.Line);
            LArea.BeginPosition.Char := 0;
            Inc(LLinesDeleted);
          end;

          FLines.DeleteText(LinesArea(LArea.EndPosition, LinesPosition(LArea.EndPosition.Char, LArea.EndPosition.Line)));
          if (Trim(FLines.Items[LArea.EndPosition.Line].Text) = '') then
          begin
            FLines.Delete(LArea.EndPosition.Line);
            Dec(LArea.EndPosition.Line);
            Inc(LLinesDeleted);
          end;

          if ((LLinesDeleted = 2) and (LArea.EndPosition >= LArea.BeginPosition)) then
            FLines.DeleteIndent(LArea.BeginPosition, LinesPosition(LArea.BeginPosition.Char, LArea.EndPosition.Line), IndentText(Tabs.Width));
        end;

        Inc(LCommentIndex, 2);

        if (LCommentIndex < LCommentLength) then
        begin
          LIndentText := IndentText(LeftSpaceCount(FLines.Items[LArea.BeginPosition.Line].Text));

          FLines.InsertText(LArea.BeginPosition, LIndentText + FHighlighter.Comments.BlockComments[LCommentIndex] + FLines.LineBreak);
          Inc(LArea.EndPosition.Line);

          if ((LArea.EndPosition.Char = 0) and (LArea.EndPosition.Line > LArea.BeginPosition.Line)) then
            LArea.EndPosition := FLines.EOLPosition[LArea.EndPosition.Line - 1];
          FLines.InsertText(LArea.EndPosition, FLines.LineBreak + LIndentText + FHighlighter.Comments.BlockComments[LCommentIndex + 1]);

          FLines.InsertIndent(FLines.BOLPosition[LArea.BeginPosition.Line + 1], LinesPosition(LArea.BeginPosition.Char, LArea.EndPosition.Line + 1), IndentText(Tabs.Width));
          Inc(LArea.EndPosition.Line);
        end;

        if (LArea.EndPosition.Line < FLines.Count - 1) then
        begin
          LArea.EndPosition := FLines.BOLPosition[LArea.EndPosition.Line + 1];
          SetSelArea(LArea);
        end
        else
          FLines.CaretPosition := FLines.BOFPosition;
      finally
        FLines.EndUpdate();
      end;
    end;
  end;
end;

procedure TCustomBCEditor.DoBlockIndent(const ACommand: TBCEditorCommand);
var
  LIndentText: string;
  LTextArea: TBCEditorLinesArea;
begin
  if (FLines.Count > 0) then
  begin
    LTextArea.BeginPosition := FLines.BOLPosition[FLines.SelArea.BeginPosition.Line];
    LTextArea.EndPosition := LinesPosition(LTextArea.BeginPosition.Char, FLines.SelArea.EndPosition.Line);
    if (LTextArea.EndPosition = LTextArea.BeginPosition) then
      if (LTextArea.EndPosition.Line < FLines.Count - 1) then
        LTextArea.EndPosition := FLines.BOLPosition[LTextArea.EndPosition.Line + 1]
      else
        LTextArea.EndPosition := FLines.EOLPosition[LTextArea.EndPosition.Line];

    LIndentText := IndentText(FTabs.Width);

    FLines.BeginUpdate();
    try
      case (ACommand) of
        ecBlockIndent:
          FLines.InsertIndent(LTextArea.BeginPosition, LTextArea.EndPosition, LIndentText);
        ecBlockUnindent:
          FLines.DeleteIndent(LTextArea.BeginPosition, LTextArea.EndPosition, LIndentText);
        else raise ERangeError.Create('ACommand: ' + IntToStr(Ord(ACommand)));
      end;

      if (FLines.SelArea.IsEmpty()) then
      begin
        LTextArea.BeginPosition.Char := 0;
        if (LTextArea.EndPosition.Char > 0) then
          LTextArea.EndPosition.Char := Length(FLines.Items[LTextArea.EndPosition.Line].Text);
        SetSelArea(LTextArea);
      end;
    finally
      FLines.EndUpdate();
    end;
  end;
end;

procedure TCustomBCEditor.DoBOL(const ASelectionCommand: Boolean);
var
  LLeftSpaceCount: Integer;
  LNewCaretPosition: TBCEditorLinesPosition;
begin
  LNewCaretPosition := FLines.CaretPosition;
  if (FWordWrap) then
    LNewCaretPosition := FRows.BORPosition[FRows.CaretPosition.Row]
  else if (FLines.CaretPosition.Line < FLines.Count) then
  begin
    LLeftSpaceCount := LeftSpaceCount(FLines.Items[LNewCaretPosition.Line].Text);
    if (LNewCaretPosition.Char > LLeftSpaceCount) then
      LNewCaretPosition.Char := LLeftSpaceCount
    else
      LNewCaretPosition.Char := 0;
  end
  else
    LNewCaretPosition := FLines.BOLPosition[LNewCaretPosition.Line];

  SetCaretPosition(LNewCaretPosition, ASelectionCommand);
end;

procedure TCustomBCEditor.DoChar(const AData: PBCEditorCommandDataChar);
begin
  DoInsertText(AData^.Char);
end;

procedure TCustomBCEditor.DoCompletionProposal();
var
  LCanExecute: Boolean;
  LColumnIndex: Integer;
  LControl: TWinControl;
  LCurrentInput: string;
  LIndex: Integer;
  LItem: TBCEditorCompletionProposalItems.TItem;
  LItems: TStrings;
  LPoint: TPoint;
begin
  Assert(FCompletionProposal.CompletionColumnIndex < FCompletionProposal.Columns.Count);

  if (esCaretInvalid in FState) then
    LPoint := FCaretPos
  else
    LPoint := RowsToClient(FRows.CaretPosition, True);
  Inc(LPoint.Y, FLineHeight);

  FCompletionProposalPopup := TBCEditorCompletionProposalPopup.Create(Self);
  with FCompletionProposalPopup do
  begin
    LControl := Self;
    while Assigned(LControl) and not (LControl is TCustomForm) do
      LControl := LControl.Parent;
    if LControl is TCustomForm then
      PopupParent := TCustomForm(LControl);
    OnClose := FOnCompletionProposalClose;
    OnValidate := FOnCompletionProposalValidate;
    Assign(FCompletionProposal);

    LItems := TStringList.Create;
    try
      if cpoParseItemsFromText in FCompletionProposal.Options then
        SplitTextIntoWords(LItems, False);
      if cpoAddHighlighterKeywords in FCompletionProposal.Options then
        AddHighlighterKeywords(LItems);
      if ((LItems.Count > 0) or not Assigned(FOnCompletionProposalShow)) then
        Items.Clear;
      for LIndex := 0 to LItems.Count - 1 do
      begin
        LItem := Items.Add;
        LItem.Value := LItems[LIndex];
        { Add empty items for columns }
        for LColumnIndex := 1 to FCompletionProposal.Columns.Count - 1 do
          FCompletionProposal.Columns[LColumnIndex].Items.Add;
      end;
    finally
      LItems.Free;
    end;

    LCurrentInput := GetCurrentInput();
    LCanExecute := True;
    if Assigned(FOnCompletionProposalShow) then
      FOnCompletionProposalShow(Self, FCompletionProposal.Columns,
        LCurrentInput, LCanExecute);
    if LCanExecute then
    begin
      DoUnselect();
      Execute(LCurrentInput, LPoint);
    end
    else
    begin
      FCompletionProposalPopup.Free;
      FCompletionProposalPopup := nil;
    end;
  end;
end;

procedure TCustomBCEditor.DoCopyToClipboard();
var
  LClipboardData: Pointer;
  LGlobal: HGLOBAL;
  LOpened: Boolean;
  LRetry: Integer;
  LText: string;
begin
  LRetry := 0;
  repeat
    LOpened := OpenClipboard(WindowHandle);
    if (not LOpened) then
    begin
      Sleep(50);
      Inc(LRetry);
    end;
  until (LOpened or (LRetry = 10));

  if (not LOpened) then
    raise EClipboardException.CreateFmt(SCannotOpenClipboard, [SysErrorMessage(GetLastError)])
  else
  begin
    try
      EmptyClipboard();
      LText := SelText;
      LGlobal := GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE, (Length(LText) + 1) * SizeOf(Char));
      if (LGlobal <> 0) then
      try
        LClipboardData := GlobalLock(LGlobal);
        if (Assigned(LClipboardData)) then
        begin
          StrPCopy(LClipboardData, LText);
          SetClipboardData(CF_UNICODETEXT, LGlobal);
        end;
      finally
        GlobalUnlock(LGlobal);
      end;
    finally
      CloseClipboard();
    end;
  end;
end;

procedure TCustomBCEditor.DoCutToClipboard();
begin
  if (FReadOnly or FLines.SelArea.IsEmpty()) then
    EmptyClipboard()
  else
  begin
    DoCopyToClipboard();
    FLines.DeleteText(FLines.SelArea);
  end;
end;

procedure TCustomBCEditor.DoDeleteToEOL();
begin
  if (FLines.ValidPosition(FLines.CaretPosition)) then
    FLines.DeleteText(LinesArea(FLines.CaretPosition, FLines.EOLPosition[FLines.CaretPosition.Line]));
end;

procedure TCustomBCEditor.DoDeleteWord();
var
  LArea: TBCEditorLinesArea;
begin
  LArea := FLines.WordArea[FLines.CaretPosition];
  if (LArea <> InvalidLinesArea) then
    FLines.DeleteText(LArea);
end;

procedure TCustomBCEditor.DoDropOLE(const AData: PBCEditorCommandDataDropOLE);
var
  LFilename: string;
  LFormat: FORMATETC;
  LLen: UINT;
  LMedium: STGMEDIUM;
  LOldPosition: TBCEditorLinesPosition;
  LText: string;
begin
  LFormat.cfFormat := CF_UNICODETEXT;
  LFormat.ptd := nil;
  LFormat.dwAspect := DVASPECT_CONTENT;
  LFormat.lindex := -1;
  LFormat.tymed := TYMED_HGLOBAL;
  if (AData^.dataObj.QueryGetData(LFormat) = S_OK) then
  begin
    OleCheck(AData^.dataObj.GetData(LFormat, LMedium));
    SetString(LText, PChar(GlobalLock(LMedium.hGlobal)), GlobalSize(LMedium.hGlobal) div SizeOf(LText[1]));
    FLines.CaretPosition := FInsertPos;
    SelText := LText;
  end
  else
  begin
    LFormat.cfFormat := CF_HDROP;
    LFormat.ptd := nil;
    LFormat.dwAspect := DVASPECT_CONTENT;
    LFormat.lindex := -1;
    LFormat.tymed := TYMED_HGLOBAL;
    OleCheck(AData^.dataObj.GetData(LFormat, LMedium));
    LLen := DragQueryFile(LMedium.hGlobal, 0, nil, 0);
    SetLength(LFilename, LLen + 1);
    Assert(DragQueryFile(LMedium.hGlobal, 0, PChar(LFilename), LLen + 1) = LLen);
    SetLength(LFilename, LLen);
    LOldPosition := FInsertPos;
    FLines.InsertFile(FInsertPos, LFilename);
    SetSelArea(LinesArea(LOldPosition, FLines.CaretPosition));
    SetInsertPos(InvalidPos);
  end;
end;

procedure TCustomBCEditor.DoEOL(const ASelectionCommand: Boolean);
var
  LNewCaretPosition: TBCEditorLinesPosition;
begin
  if (FRows.CaretPosition.Row < FRows.Count) then
    LNewCaretPosition := FRows.EORPosition[FRows.CaretPosition.Row]
  else
    LNewCaretPosition := FLines.BOLPosition[FLines.CaretPosition.Line];
  SetCaretPosition(LNewCaretPosition, ASelectionCommand);
end;

procedure TCustomBCEditor.DoEOF(const ACommand: TBCEditorCommand);
begin
  FBuildRowsCriticalSection.Enter();
  try
    if (FLines.Count = 0) then
      SetCaretPosition(FLines.BOFPosition, False)
    else if (rsBuilding in FRows.State) then
    begin
      FRowsWanted.What := rwEOF;
      FRowsWanted.Select := ACommand = ecSelEOF;
      UpdateCursor();
    end
    else
      SetCaretPosition(FLines.EOLPosition[FRows.Items[FRows.Count - 1].Line], ACommand = ecSelEOF);
  finally
    FBuildRowsCriticalSection.Leave();
  end;
end;

procedure TCustomBCEditor.DoBOF(const ACommand: TBCEditorCommand);
begin
  SetCaretPosition(FLines.BOFPosition, ACommand = ecSelBOF);
end;

function TCustomBCEditor.DoFindBackwards(const AData: PBCEditorCommandDataFind): Boolean;
var
  LFindResult: TBCEditorLines.TSearchResult;
  LIndex: Integer;
  LLeft: Integer;
  LMiddle: Integer;
  LRight: Integer;
begin
  Result := FLines.FoundAreas.Count > 0;

  if (Result) then
  begin
    if (FLines.CaretPosition > FLines.FoundAreas[FLines.FoundAreas.Count - 1].BeginPosition) then
      LIndex := FLines.FoundAreas.Count - 1
    else if (FLines.CaretPosition > FLines.FoundAreas[0].BeginPosition) then
    begin
      LIndex := -1;

      LLeft := 0;
      LRight := FLines.FoundAreas.Count - 1;

      while (LIndex < 0) do
      begin
        LMiddle := (LLeft + LRight) div 2;
        if (FLines.FoundAreas[LMiddle].BeginPosition < FLines.CaretPosition) then
          LLeft := LMiddle + 1
        else if ((FLines.FoundAreas[LMiddle - 1].BeginPosition < FLines.CaretPosition)
          and (FLines.CaretPosition <= FLines.FoundAreas[LMiddle].BeginPosition)) then
          LIndex := LMiddle - 1
        else
          LRight := LMiddle - 1;
      end;
    end
    else if (AskSearchWrapAround(AData)) then
      LIndex := FLines.FoundAreas.Count - 1
    else
      LIndex := -1;

    Result := LIndex >= 0;

    if (not Result) then
    begin
      LFindResult.Area := InvalidLinesArea;
      LFindResult.ErrorMessage := Format(SBCEditorSearchNotFound, [AData^.Pattern]);
    end
    else
    begin
      LFindResult.Area := FLines.FoundAreas[LIndex];
      LFindResult.ErrorMessage := '';
    end;
    LFindResult.Backwards := False;
    LFindResult.Count := -1;
    FindExecuted(@LFindResult);
  end;
end;

procedure TCustomBCEditor.DoFindFirst(const AData: PBCEditorCommandDataFind);
var
  LSearch: TBCEditorLines.TSearch;
  LSearchArea: TBCEditorLinesArea;
begin
  if ((foSelection in AData^.Options) and not FLines.SelArea.IsEmpty()) then
    FFindArea := FLines.SelArea
  else
    FFindArea := FLines.Area;

  if (FLines.Count = 0) then
    FFindPosition := FLines.BOFPosition
  else if (not (foEntireScope in AData^.Options)) then
  begin
    FFindPosition.Line := Min(FLines.CaretPosition.Line, FLines.Count - 1);
    FFindPosition.Char := Min(FLines.CaretPosition.Char, Length(FLines[FLines.CaretPosition.Line]));
  end
  else if (foBackwards in AData^.Options) then
    FFindPosition := FLines.EOFPosition
  else
    FFindPosition := FLines.BOFPosition;

  FFindState := fsRequested;

  if (foEntireScope in AData^.Options) then
    LSearchArea := FFindArea
  else if (foBackwards in AData^.Options) then
    LSearchArea := LinesArea(FFindArea.BeginPosition, FFindPosition)
  else
    LSearchArea := LinesArea(FFindPosition, FFindArea.EndPosition);

  LSearch := TBCEditorLines.TSearch.Create(FLines,
    LSearchArea,
    foCaseSensitive in AData^.Options, foWholeWordsOnly in AData^.Options, foRegExpr in AData^.Options,
    AData^.Pattern);

  FLines.StartSearch(LSearch, FFindPosition, False, True, foBackwards in AData^.Options, FindExecuted);
  UpdateCursor();

  Sleep(GClientRefreshTime); // If search is fast enough, prevent double painting
end;

function TCustomBCEditor.DoFindForewards(const AData: PBCEditorCommandDataFind): Boolean;
var
  LFindResult: TBCEditorLines.TSearchResult;
  LIndex: Integer;
  LLeft: Integer;
  LMiddle: Integer;
  LRight: Integer;
begin
  Result := FLines.FoundAreas.Count > 0;

  if (Result) then
  begin
    if (FLines.CaretPosition <= FLines.FoundAreas[0].BeginPosition) then
      LIndex := 0
    else if (FLines.CaretPosition <= FLines.FoundAreas[FLines.FoundAreas.Count - 1].BeginPosition) then
    begin
      LIndex := -1;

      LLeft := 0;
      LRight := FLines.FoundAreas.Count - 1;

      while (LIndex < 0) do
      begin
        LMiddle := (LLeft + LRight) div 2;
        if (FLines.FoundAreas[LMiddle].BeginPosition < FLines.CaretPosition) then
          LLeft := LMiddle + 1
        else if ((FLines.FoundAreas[LMiddle - 1].BeginPosition < FLines.CaretPosition)
          and (FLines.CaretPosition <= FLines.FoundAreas[LMiddle].BeginPosition)) then
          LIndex := LMiddle
        else
          LRight := LMiddle - 1;
      end;
    end
    else if (AskSearchWrapAround(AData)) then
      LIndex := 0
    else
      LIndex := -1;

    Result := LIndex >= 0;

    if (not Result) then
    begin
      LFindResult.Area := InvalidLinesArea;
      LFindResult.ErrorMessage := Format(SBCEditorSearchNotFound, [AData^.Pattern]);
    end
    else
    begin
      LFindResult.Area := FLines.FoundAreas[LIndex];
      LFindResult.ErrorMessage := '';
    end;
    LFindResult.Backwards := False;
    LFindResult.Count := -1;
    FindExecuted(@LFindResult);
  end;
end;

procedure TCustomBCEditor.DoInsertText(const AText: string);
begin
  BeginUpdate();
  try
    if (not FLines.SelArea.IsEmpty()) then
      FLines.ReplaceText(FLines.SelArea, AText)
    else if ((FTextEntryMode = temOverwrite)
      and (FLines.CaretPosition.Line < FLines.Count)
      and (FLines.CaretPosition.Char < Length(FLines.Items[FLines.CaretPosition.Line].Text))) then
      FLines.ReplaceText(LinesArea(FLines.CaretPosition, LinesPosition(FLines.CaretPosition.Char + 1, FLines.CaretPosition.Line)), AText)
    else
      FLines.InsertText(FLines.CaretPosition, AText);
  finally
    EndUpdate();
  end;
end;

procedure TCustomBCEditor.DoLineComment();
var
  LArea: TBCEditorLinesArea;
  LComment: Integer;
  LCommentsCount: Integer;
  LCurrentComment: Integer;
  LOpenToken: string;
begin
  LCommentsCount := Length(FHighlighter.Comments.LineComments);
  if (LCommentsCount > 0) then
  begin
    LArea.BeginPosition := FLines.BOLPosition[FLines.SelArea.BeginPosition.Line];
    LArea.EndPosition := LinesPosition(LArea.BeginPosition.Char, FLines.SelArea.EndPosition.Line);

    if (LArea.BeginPosition.Line < FLines.Count) then
    begin
      LCurrentComment := -1;
      for LComment := LCommentsCount - 1 downto 0 do
        if (Copy(FLines.Items[LArea.BeginPosition.Line].Text, 1 + LArea.BeginPosition.Char, Length(FHighlighter.Comments.LineComments[LComment])) = FHighlighter.Comments.LineComments[LComment]) then
          LCurrentComment := LComment;
      if (LCurrentComment < 0) then
        LOpenToken := ''
      else
        LOpenToken := FHighlighter.Comments.LineComments[LCurrentComment];

      FLines.BeginUpdate();
      try
        if (LCurrentComment >= 0) then
        begin
          FLines.DeleteIndent(LArea.BeginPosition, LArea.EndPosition,
            FHighlighter.Comments.LineComments[LCurrentComment]);
        end;

        if ((LCurrentComment < 0)
          or (LArea.BeginPosition.Line <> LArea.EndPosition.Line) and (LCurrentComment < LCommentsCount - 1)) then
        begin
          Inc(LCurrentComment);

          FLines.InsertIndent(LArea.BeginPosition, LArea.EndPosition,
            FHighlighter.Comments.LineComments[LCurrentComment]);
        end;

        if (FLines.SelArea.IsEmpty()) then
        begin
          LArea.BeginPosition.Char := 0;
          if (LArea.EndPosition.Char > 0) then
            LArea.EndPosition := FLines.EOLPosition[LArea.EndPosition.Line]
          else if (LArea.IsEmpty() and (LArea.EndPosition.Line < FLines.Count - 1)) then
            LArea := LinesArea(FLines.BOLPosition[LArea.EndPosition.Line + 1], FLines.BOLPosition[LArea.EndPosition.Line + 1]);
          SetSelArea(LArea);
        end;
      finally
        FLines.EndUpdate();
      end;
    end;
  end;
end;

function TCustomBCEditor.DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  if (esScrolling in FState) then
    ProcessClient(cjMouseDown, nil, nil, FMetrics.ClientRect, mbMiddle, [], FScrollingPoint);

  Result := inherited;

  if (not Result) then
  begin
    if (ssCtrl in Shift) then
      ScrollTo(FTextPos.X, FTextPos.Y + FUsableRows * FLineHeight)
    else if (ssShift in Shift) then
    begin
      if (FRows.CaretPosition.Row < FRows.Count - 2) then
        DoUpOrDown(Mouse.WheelScrollLines, False);
    end
    else
      ScrollTo(FTextPos.X, FTextPos.Y + Mouse.WheelScrollLines * FLineHeight);
    Result := True;
  end;
end;

function TCustomBCEditor.DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  if (esScrolling in FState) then
    ProcessClient(cjMouseDown, nil, nil, FMetrics.ClientRect, mbMiddle, [], FScrollingPoint);

  Result := inherited;

  if (not Result) then
  begin
    if (ssCtrl in Shift) then
      ScrollTo(FTextPos.X, FTextPos.Y - FUsableRows * FLineHeight)
    else if (ssShift in Shift) then
    begin
      if (FRows.CaretPosition.Row > 0) then
        DoUpOrDown(- Mouse.WheelScrollLines, False);
    end
    else
      ScrollTo(FTextPos.X, FTextPos.Y - Mouse.WheelScrollLines * FLineHeight);
    Result := True;
  end;
end;

procedure TCustomBCEditor.DoPageTopOrBottom(const ACommand: TBCEditorCommand);
var
  LNewRow: Integer;
begin
  case (ACommand) of
    ecPageTop,
    ecSelBOP:
      LNewRow := FTopRow;
    ecPageBottom,
    ecSelEOP:
      LNewRow := FTopRow + FUsableRows - 1;
    else raise ERangeError.Create('ACommand: ' + IntToStr(Ord(ACommand)));
  end;

  SetCaretPosition(RowsToLines(RowsPosition(FRows.CaretPosition.Column, LNewRow)), ACommand in [ecSelBOP, ecSelEOP]);
end;

procedure TCustomBCEditor.DoPageUpOrDown(const ACommand: TBCEditorCommand);
begin
  BeginUpdate();
  try
    case (ACommand) of
      ecPageUp, ecSelPageUp:
        begin
          SetTextPos(FTextPos.X, FTextPos.Y - FUsableRows * FLineHeight);
          DoUpOrDown(- FUsableRows, ACommand = ecSelPageUp);
        end;
      ecPageDown, ecSelPageDown:
        begin
          SetTextPos(FTextPos.X, FTextPos.Y + FUsableRows * FLineHeight);
          DoUpOrDown(FUsableRows, ACommand = ecSelPageDown);
        end;
    end;
  finally
    EndUpdate();
  end;
end;

procedure TCustomBCEditor.DoPosition(const AData: PBCEditorCommandDataPosition);
begin
  SetCaretPosition(AData^.Pos, AData^.Selection);
end;

procedure TCustomBCEditor.DoRedo();
begin
  Redo();
end;

procedure TCustomBCEditor.DoReplace(const AData: TBCEditorCommandData);
var
  LArea: TBCEditorLinesArea;
  LData: PBCEditorCommandDataReplace;
  LSearch: TBCEditorLines.TSearch;
  LSearchPosition: TBCEditorLinesPosition;
begin
  LData := @AData[0];

  if ((roSelection in LData^.Options) and not FLines.SelArea.IsEmpty()) then
    LArea := FLines.SelArea
  else
    LArea := FLines.Area;
  if (not (roEntireScope in LData^.Options) and not (roSelection in LData^.Options)) then
    if (roBackwards in LData^.Options) then
      LArea.EndPosition := FLines.CaretPosition
    else
      LArea.BeginPosition := FLines.CaretPosition;

  if ((Length(LData^.Pattern) > 0) and not (LArea.IsEmpty())) then
  begin
    LSearch := TBCEditorLines.TSearch.Create(FLines,
      LArea,
      roCaseSensitive in LData^.Options, roWholeWordsOnly in LData^.Options, roRegExpr in LData^.Options,
      LData^.Pattern,
      sjFindAndReplace, LData^.ReplaceText, roPrompt in LData^.Options);

    if (FLines.Count = 0) then
      LSearchPosition := FLines.BOFPosition
    else if (not (roSelection in LData^.Options)) then
    begin
      LSearchPosition := FLines.CaretPosition;
      LSearchPosition.Line := Min(LSearchPosition.Line, FLines.Count - 1);
      LSearchPosition.Char := Min(LSearchPosition.Char, Length(FLines[LSearchPosition.Line]));
    end
    else if (roBackwards in LData^.Options) then
      LSearchPosition := FLines.SelArea.EndPosition
    else
      LSearchPosition := FLines.SelArea.BeginPosition;

    FLines.StartSearch(LSearch, LSearchPosition, roReplaceAll in LData^.Options, True, roBackwards in LData^.Options, ReplaceExecuted);
  end;
end;

procedure TCustomBCEditor.DoReturnKey();
var
  LInsertText: string;
begin
  if (not FLines.SelArea.IsEmpty()) then
    SelText := ''
  else if (FLines.CaretPosition.Line >= FLines.Count) then
    FLines.CaretPosition := FLines.BOLPosition[FLines.CaretPosition.Line + 1]
  else if (FTextEntryMode = temInsert) then
  begin
    LInsertText := FLines.LineBreak;
    if ((FLines.CaretPosition.Char > 0) and (eoAutoIndent in FOptions)) then
      LInsertText := LInsertText + IndentText(Min(FRows.CaretPosition.Column, LeftSpaceCount(FLines.Items[FLines.CaretPosition.Line].Text, True)));
    FLines.InsertText(FLines.CaretPosition, LInsertText);
  end
  else
  begin
    if ((FLines.CaretPosition.Char > 0) and (eoAutoIndent in FOptions)) then
      FLines.CaretPosition := LinesPosition(Min(FLines.CaretPosition.Char, LeftSpaceCount(FLines.Items[FLines.CaretPosition.Line].Text, True)), FLines.CaretPosition.Line + 1)
    else
      FLines.CaretPosition := FLines.BOLPosition[FLines.CaretPosition.Line + 1];
  end;
end;

procedure TCustomBCEditor.DoScroll(const ACommand: TBCEditorCommand);
begin
  case (ACommand) of
    ecScrollUp:
      SetTextPos(FTextPos.X, FTextPos.Y - FLineHeight);
    ecScrollDown:
      SetTextPos(FTextPos.X, FTextPos.Y + FLineHeight);
    ecScrollLeft:
      SetTextPos(FTextPos.X - FHorzScrollBarDivider * FSpaceWidth, FTextPos.Y);
    ecScrollRight:
      SetTextPos(FTextPos.X + FHorzScrollBarDivider * FSpaceWidth, FTextPos.Y);
  end;
end;

procedure TCustomBCEditor.DoScrollTo(const AData: TBCEditorCommandData);
var
  LData: PBCEditorCommandDataScrollTo;
begin
  LData := @AData[0];

  SetTextPos(LData^.Pos);
end;

procedure TCustomBCEditor.DoSelectAll();
begin
  SetSelArea(FLines.Area);
end;

procedure TCustomBCEditor.DoSelection(const AData: PBCEditorCommandDataSelection);
begin
  SetSelArea(LinesArea(AData^.BeginPos, AData^.EndPos), AData^.CaretToBeginPosition);
end;

procedure TCustomBCEditor.DoShowFind(const First: Boolean);
begin
  if (not Assigned(FFindDialog)) then
  begin
    FFindDialog := TFindDialog.Create(Self);
    FFindDialog.Options := FFindDialog.Options - [frMatchCase, frWholeWord] + [frDown];
    FFindDialog.OnFind := FindDialogFind;
    FFindDialog.OnClose := FindDialogClose;
  end;

  FHideSelectionBeforeSearch := HideSelection;
  HideSelection := False;

  FFindDialog.Execute();
end;

procedure TCustomBCEditor.DoShowGotoLine();
begin
  if (not Assigned(FGotoLineDialog)) then
    FGotoLineDialog := TGotoLineDialog.Create(Self);

  FGotoLineDialog.Min := FLeftMargin.LineNumbers.Offset;
  FGotoLineDialog.Max := Max(1, FLines.Count) + FLeftMargin.LineNumbers.Offset;
  FGotoLineDialog.Line := FLines.CaretPosition.Line + FLeftMargin.LineNumbers.Offset;
  if (FGotoLineDialog.Execute()) then
  begin
    Include(FState, esCenterCaret);
    try
      FLines.CaretPosition := FLines.BOLPosition[FGotoLineDialog.Line - FLeftMargin.LineNumbers.Offset];
    finally
      Exclude(FState, esCenterCaret);
    end;
  end;
end;

procedure TCustomBCEditor.DoShowReplace();
begin
  if (not Assigned(FReplaceDialog)) then
  begin
    FReplaceDialog := TReplaceDialog.Create(Self);
    FReplaceDialog.FindText := '';
    FReplaceDialog.ReplaceText := '';
    FReplaceDialog.Options := FReplaceDialog.Options - [frMatchCase, frWholeWord, frReplaceAll];
    FReplaceDialog.OnClose := FindDialogClose;
    FReplaceDialog.OnFind := ReplaceDialogFind;
    FReplaceDialog.OnReplace := ReplaceDialogReplace;
  end;

  FHideSelectionBeforeSearch := HideSelection;
  HideSelection := False;

  FReplaceDialog.Execute();
end;

procedure TCustomBCEditor.DoSetBookmark(const ACommand: TBCEditorCommand);
var
  LIndex: Integer;
begin
  LIndex := Ord(ACommand) - Ord(ecSetBookmark1);
  if not DeleteBookmark(FLines.CaretPosition.Line, LIndex) then
    SetBookmark(LIndex, FLines.CaretPosition);
end;

procedure TCustomBCEditor.DoSyncEdit();
begin
  if (FLines.SyncEdit) then
  begin
    FLines.ActivateSyncEdit(FHighlighter, SyncEditActivated);
    UpdateCursor();

    InvalidateText();

    Sleep(GClientRefreshTime); // If activation is fast enough, prevent double painting
  end
  else
  begin
    FLines.DeactivateSyncEdit();

    UpdateCursor();
    InvalidateText();
  end;
end;

procedure TCustomBCEditor.DoTabKey(const ACommand: TBCEditorCommand);
var
  LChangeScrollPastEndOfLine: Boolean;
  LCharCount: Integer;
  LIndex: Integer;
  LLengthAfterLine: Integer;
  LNewCaretPosition: TBCEditorLinesPosition;
  LPreviousLine: Integer;
  LPreviousLineCharCount: Integer;
  LRowsPosition: TBCEditorRowsPosition;
  LTabText: string;
  LTabWidth: Integer;
  LLinesCaretPosition: TBCEditorLinesPosition;
begin
  if (not FLines.SyncEdit) then
    LIndex := -1
  else
    LIndex := FLines.SyncEditItemIndexOf(FLines.CaretPosition);

  case (ACommand) of
    ecTab:
      begin
        if (LIndex >= 0) then
        begin
          if (LIndex < FLines.SyncEditItems.Count - 1) then
            Inc(LIndex)
          else
            LIndex := 0;
          SetSelArea(FLines.SyncEditItems[LIndex].Area, True);
        end
        else if ((FLines.SelArea.BeginPosition.Line <> FLines.SelArea.EndPosition.Line)
          and (toSelectedBlockIndent in FTabs.Options)) then
          DoBlockIndent(ecBlockIndent)
        else if (not FLines.SelArea.IsEmpty() or
          (FLines.CaretPosition.Line >= FLines.Count)) then
        begin
          if (not (toTabsToSpaces in FTabs.Options)) then
          begin
            LTabText := StringOfChar(BCEDITOR_TAB_CHAR, FTabs.Width div FTabs.Width);
            LTabText := LTabText + StringOfChar(BCEDITOR_TAB_CHAR, FTabs.Width mod FTabs.Width);
          end
          else
            LTabText := StringOfChar(BCEDITOR_SPACE_CHAR, FTabs.Width - (FRows.CaretPosition.Column - 1) mod FTabs.Width);
          DoInsertText(LTabText);
        end
        else
        begin
          FLines.BeginUpdate();
          try
            LLinesCaretPosition := FLines.CaretPosition;

            LRowsPosition := FRows.CaretPosition;
            LLengthAfterLine := Max(0, LRowsPosition.Column - FRows.Items[LRowsPosition.Row].Columns);

            if LLengthAfterLine > 1 then
              LCharCount := LLengthAfterLine
            else
              LCharCount := FTabs.Width;

            if toPreviousLineIndent in FTabs.Options then
              if Trim(FLines.Items[LLinesCaretPosition.Line].Text) = '' then
              begin
                LPreviousLine := LLinesCaretPosition.Line - 1;
                while (LPreviousLine >= 0) and (FLines.Items[LPreviousLine].Text = '') do
                  Dec(LPreviousLine);
                LPreviousLineCharCount := LeftSpaceCount(FLines.Items[LPreviousLine].Text, True);
                if LPreviousLineCharCount > LLinesCaretPosition.Char + 1 then
                  LCharCount := LPreviousLineCharCount - LeftSpaceCount(FLines.Items[LLinesCaretPosition.Line].Text, True)
              end;

            if LLengthAfterLine > 1 then
              LLinesCaretPosition := FLines.BOLPosition[LLinesCaretPosition.Line];

            if (not (toTabsToSpaces in FTabs.Options)) then
            begin
              LTabText := StringOfChar(BCEDITOR_TAB_CHAR, LCharCount div FTabs.Width);
              LTabText := LTabText + StringOfChar(BCEDITOR_TAB_CHAR, LCharCount mod FTabs.Width);
            end
            else
              LTabText := StringOfChar(BCEDITOR_SPACE_CHAR, LCharCount - (LRowsPosition.Column - 1) mod FTabs.Width);

            if FTextEntryMode = temInsert then
              FLines.InsertText(LLinesCaretPosition, LTabText);

            LChangeScrollPastEndOfLine := not (loBeyondEOL in FLines.Options);
            try
              if LChangeScrollPastEndOfLine then
                FLines.Options := FLines.Options + [loBeyondEOL];
              if FTextEntryMode = temOverwrite then
                LTabText := StringReplace(LTabText, BCEDITOR_TAB_CHAR, StringOfChar(BCEDITOR_SPACE_CHAR, FTabs.Width),
                  [rfReplaceAll]);
              FLines.CaretPosition := LinesPosition(LLinesCaretPosition.Char + Length(LTabText), FLines.CaretPosition.Line);
            finally
              if LChangeScrollPastEndOfLine then
                FLines.Options := FLines.Options - [loBeyondEOL];
            end;
          finally
            FLines.EndUpdate();
          end;
        end;
      end;
    ecShiftTab:
      begin
        if (FLines.SelArea.IsEmpty()) then
        begin
          if (FRows.CaretPosition.Column > 0) then
            if (FLines.Char[LinesPosition(FLines.CaretPosition.Char - 1, FLines.CaretPosition.Line)] = BCEDITOR_TAB_CHAR) then
              FLines.CaretPosition := LinesPosition(FLines.CaretPosition.Char - 1, FLines.CaretPosition.Line)
            else if (FRows.CaretPosition.Column mod FTabs.Width = 0) then
              FLines.CaretPosition := RowsToLines(RowsPosition(FRows.CaretPosition.Column - FTabs.Width, FRows.CaretPosition.Row))
            else
              FLines.CaretPosition := RowsToLines(RowsPosition(FRows.CaretPosition.Column - FRows.CaretPosition.Column mod FTabs.Width, FRows.CaretPosition.Row));
        end
        else if (LIndex >= 0) then
        begin
          if (LIndex = 0) then
            LIndex := FLines.SyncEditItems.Count - 1
          else
            Dec(LIndex);
          SetSelArea(FLines.SyncEditItems[LIndex].Area, True);
        end
        else if ((toSelectedBlockIndent in FTabs.Options) and not FLines.SelArea.IsEmpty()) then
          DoBlockIndent(ecBlockUnindent)
        else
        begin
          if (toTabsToSpaces in FTabs.Options) then
            LTabWidth := FTabs.Width
          else
            LTabWidth := 1;
          LNewCaretPosition := LinesPosition(Max(0, FLines.CaretPosition.Char - LTabWidth + 1), FLines.CaretPosition.Line);

          if ((LNewCaretPosition <> FLines.CaretPosition)
            and (Copy(FLines.Items[FLines.CaretPosition.Line].Text, 1 + LNewCaretPosition.Char, LTabWidth) = BCEDITOR_TAB_CHAR)) then
            FLines.DeleteText(LinesArea(LNewCaretPosition, FLines.CaretPosition));
        end;
      end;
  end;
end;

procedure TCustomBCEditor.DoText(const AData: PBCEditorCommandDataText);
var
  LOldCaretPosition: TBCEditorLinesPosition;
begin
  FLines.BeginUpdate();
  try
    if (AData.Delete and not FLines.SelArea.IsEmpty()) then
      FLines.DeleteText(FLines.SelArea);
    LOldCaretPosition := FLines.CaretPosition;
    FLines.InsertText(FLines.CaretPosition, AData^.Text);
    if (AData.Selection) then
      SetSelArea(LinesArea(LOldCaretPosition, FLines.CaretPosition));
  finally
    FLines.EndUpdate();
  end;
end;

procedure TCustomBCEditor.DoToggleSelectedCase(const ACommand: TBCEditorCommand);
var
  LSelectedText: string;
begin
  if (not FLines.SelArea.IsEmpty()) then
  begin
    LSelectedText := SelText;
    case (ACommand) of
      ecUpperCase:
        SelText := AnsiUpperCase(LSelectedText);
      ecLowerCase:
        SelText := AnsiLowerCase(LSelectedText);
      else ERangeError.Create('ACommand: ' + IntToStr(Ord(ACommand)));
    end;
  end;
end;

procedure TCustomBCEditor.DoTripleClick();
begin
  FLines.SelArea := FLines.LineArea[FLines.CaretPosition.Line];

  FLastDoubleClickTime := 0;
end;

procedure TCustomBCEditor.DoUndo();
begin
  Undo();
end;

procedure TCustomBCEditor.DoUnselect();
begin
  FLines.SelArea := LinesArea(FLines.CaretPosition, FLines.CaretPosition);
end;

procedure TCustomBCEditor.DoUpOrDown(const ARows: Integer; const ASelect: Boolean);
var
  LNewCaretPosition: TBCEditorRowsPosition;
  LX: Integer;
begin
  FBuildRowsCriticalSection.Enter();

  LNewCaretPosition := FRows.CaretPosition;
  Inc(LNewCaretPosition.Row, ARows);

  if ((rsBuilding in FRows.State) and (LNewCaretPosition.Row >= FRows.Count)) then
  begin
    FRowsWanted.What := rwDown;
    FRowsWanted.Row := LNewCaretPosition.Row;
    FRowsWanted.Select := ASelect;
    UpdateCursor();
  end
  else
  begin
    if (not (eoBeyondEndOfFile in FOptions)) then
      LNewCaretPosition.Row := Min(LNewCaretPosition.Row, FRows.Count - 1);
    LNewCaretPosition.Row := Max(0, LNewCaretPosition.Row);

    if (not InvalidPoint(FCaretPos)) then
      LX := FCaretPos.X
    else
      LX := RowsToClient(FRows.CaretPosition).X;
    LNewCaretPosition.Column := ClientToRows(LX, LNewCaretPosition.Row * FLineHeight, True).Column;

    if (not (eoBeyondEndOfLine in FOptions) or FWordWrap) then
      if (LNewCaretPosition.Row < FRows.Count) then
        if (not (rfLastRowOfLine in FRows.Items[LNewCaretPosition.Row].Flags)) then
          LNewCaretPosition.Column := Min(LNewCaretPosition.Column, FRows.Items[LNewCaretPosition.Row].Length - 1)
        else
          LNewCaretPosition.Column := Min(LNewCaretPosition.Column, FRows.Items[LNewCaretPosition.Row].Length)
      else
        LNewCaretPosition.Column := 0;

    SetCaretPosition(RowsToLines(LNewCaretPosition), ASelect);
  end;

  FBuildRowsCriticalSection.Leave();
end;

procedure TCustomBCEditor.DoWordLeft(const ACommand: TBCEditorCommand);
var
  LNewCaretPosition: TBCEditorLinesPosition;
begin
  if ((FLines.CaretPosition.Line = 0) and (FLines.Count = 0)) then
    FLines.CaretPosition := FLines.BOFPosition
  else if (FLines.CaretPosition.Line < FLines.Count) then
  begin
    LNewCaretPosition := FLines.CaretPosition;
    if (LNewCaretPosition.Line >= FLines.Count) then
      LNewCaretPosition := FLines.EOLPosition[FLines.Count - 1];
    if ((LNewCaretPosition.Char = 0)
      or (LNewCaretPosition.Char >= Length(FLines.Items[LNewCaretPosition.Line].Text))
      or IsWordBreakChar(FLines.Items[LNewCaretPosition.Line].Text[1 + LNewCaretPosition.Char - 1])) then
      LNewCaretPosition := PreviousWordPosition(LNewCaretPosition);
    if ((LNewCaretPosition.Char > 0)
      and ((LNewCaretPosition = FLines.CaretPosition) or (LNewCaretPosition.Char < Length(FLines.Items[LNewCaretPosition.Line].Text)))
      and not IsWordBreakChar(FLines.Items[LNewCaretPosition.Line].Text[1 + LNewCaretPosition.Char - 1])) then
      LNewCaretPosition := WordBegin(LNewCaretPosition);
    SetCaretPosition(LNewCaretPosition, ACommand = ecSelWordLeft);
  end
  else if (FLines.CaretPosition.Line = FLines.Count) then
    FLines.CaretPosition := FLines.EOLPosition[FLines.CaretPosition.Line - 1]
  else
    FLines.CaretPosition := FLines.BOLPosition[FLines.CaretPosition.Line - 1];
end;

procedure TCustomBCEditor.DoWordRight(const ACommand: TBCEditorCommand);
var
  LNewCaretPosition: TBCEditorLinesPosition;
begin
  LNewCaretPosition := FLines.CaretPosition;
  if (LNewCaretPosition.Line < FLines.Count) then
  begin
    if ((LNewCaretPosition.Char < Length(FLines.Items[LNewCaretPosition.Line].Text))
      and not IsWordBreakChar(FLines.Char[LNewCaretPosition])) then
    begin
      LNewCaretPosition := WordEnd();
      Inc(LNewCaretPosition.Char);
      while ((LNewCaretPosition.Char < Length(FLines.Items[LNewCaretPosition.Line].Text))) and IsEmptyChar(FLines.Char[LNewCaretPosition]) do
        Inc(LNewCaretPosition.Char);
    end;
    if ((LNewCaretPosition.Char >= Length(FLines.Items[LNewCaretPosition.Line].Text))
      or IsWordBreakChar(FLines.Char[LNewCaretPosition])) then
      LNewCaretPosition := NextWordPosition(LNewCaretPosition);
    SetCaretPosition(LNewCaretPosition, ACommand = ecSelWordRight);
  end;
end;

procedure TCustomBCEditor.DragCanceled();
begin
  inherited;

  SetInsertPos(InvalidPos);
end;

procedure TCustomBCEditor.DragDrop(ASource: TObject; X, Y: Integer);
begin
  if (not FReadOnly) then
  begin
    inherited;

    SetInsertPos(InvalidPos);
  end;
end;

function TCustomBCEditor.DragEnter(const dataObj: IDataObject; grfKeyState: Longint;
  pt: TPoint; var dwEffect: Longint): HResult;
var
  LFormat: FORMATETC;
  LMedium: STGMEDIUM;
begin
  if (dwEffect = DROPEFFECT_NONE) then
    Result := E_INVALIDARG
  else
  begin
    LFormat.cfFormat := CF_UNICODETEXT;
    LFormat.ptd := nil;
    LFormat.dwAspect := DVASPECT_CONTENT;
    LFormat.lindex := -1;
    LFormat.tymed := TYMED_HGLOBAL;

    if (dataObj.QueryGetData(LFormat) = S_OK) then
      Result := DragOver(grfKeyState, pt, dwEffect)
    else
    begin
      LFormat.cfFormat := CF_HDROP;
      LFormat.ptd := nil;
      LFormat.dwAspect := DVASPECT_CONTENT;
      LFormat.lindex := -1;
      LFormat.tymed := TYMED_HGLOBAL;

      if (not (eoDropFiles in FOptions) or (dataObj.QueryGetData(LFormat) <> S_OK)) then
        Result := E_UNEXPECTED
      else
      begin
        OleCheck(dataObj.GetData(LFormat, LMedium));
        if (DragQueryFile(LMedium.hGlobal, $FFFFFFFF, nil, 0) <> 1) then
          Result := E_UNEXPECTED
        else
          Result := DragOver(grfKeyState, pt, dwEffect);
      end;
    end;
  end;
end;

function TCustomBCEditor.DragLeave(): HResult;
begin
  SetInsertPos(InvalidPos);

  Result := S_OK;
end;

function TCustomBCEditor.DragOver(grfKeyState: Longint; pt: TPoint; var dwEffect: Longint): HResult;
var
  LPosition: TBCEditorLinesPosition;
  LScreen: TPoint;
begin
  if (FReadOnly
    or (pt.X <= FLeftMarginWidth)) then
  begin
    SetInsertPos(InvalidPos);
    dwEffect := DROPEFFECT_NONE;
  end
  else
  begin
    LScreen := ScreenToClient(pt);
    LPosition := ClientToLines(LScreen.X, LScreen.Y);
    if (FLines.SelArea.Contains(LPosition)
      or not ProcessCommand(ecAcceptDrop, TBCEditorCommandDataPosition.Create(LPosition))) then
    begin
      SetInsertPos(InvalidPos);
      dwEffect := DROPEFFECT_NONE;
    end
    else
    begin
      SetInsertPos(LPosition);
      if (grfKeyState and MK_CONTROL <> 0) then
        dwEffect := DROPEFFECT_COPY
      else if (grfKeyState and MK_SHIFT <> 0) then
        dwEffect := DROPEFFECT_MOVE
      else if (esDragging in FState) then
        dwEffect := DROPEFFECT_MOVE
      else
        dwEffect := DROPEFFECT_COPY;
    end;
  end;
  Result := S_OK;
end;

procedure TCustomBCEditor.DragOver(ASource: TObject; X, Y: Integer;
  AState: TDragState; var AAccept: Boolean);
var
  LPosition: TBCEditorLinesPosition;
  LScreen: TPoint;
begin
  LScreen := ScreenToClient(Point(X, Y));
  LPosition := ClientToLines(LScreen.X, LScreen.Y);
  AAccept := not FReadOnly and not ProcessCommand(ecAcceptDrop, TBCEditorCommandDataPosition.Create(LPosition));

  if (AAccept) then
    inherited;
end;

function TCustomBCEditor.Drop(const dataObj: IDataObject; grfKeyState: Longint; pt: TPoint;
  var dwEffect: Longint): HResult;
var
  LMedium: STGMEDIUM;
  LText: string;
begin
  if (dwEffect and (DROPEFFECT_COPY or DROPEFFECT_MOVE) = 0) then
    Result := E_INVALIDARG
  else
  begin
    LText := '';

    if (not ProcessCommand(ecDropOLE, TBCEditorCommandDataDropOLE.Create(FInsertPos, dataObj))) then
      Result := E_UNEXPECTED
    else
    begin
      if (grfKeyState and MK_CONTROL <> 0) then
        dwEffect := DROPEFFECT_COPY
      else if (grfKeyState and MK_SHIFT <> 0) then
        dwEffect := DROPEFFECT_MOVE
      else if (esDragging in FState) then
        dwEffect := DROPEFFECT_MOVE
      else
        dwEffect := DROPEFFECT_COPY;

      if (not Assigned(LMedium.unkForRelease)) then
        ReleaseStgMedium(LMedium)
      else
        IUnknown(LMedium.unkForRelease)._Release();

      Result := S_OK;
    end;

    if (Result = S_OK) then
      Result := DragLeave();
  end;
end;

procedure TCustomBCEditor.EMCanUndo(var AMessage: TMessage);
begin
  AMessage.Result := LRESULT(CanUndo);
end;

procedure TCustomBCEditor.EMCharFromPos(var AMessage: TMessage);
var
  LPosition: TBCEditorLinesPosition;
begin
  LPosition := ClientToLines(AMessage.LParamLo, AMessage.LParamHi, True);
  AMessage.ResultLo := LPosition.Char;
  AMessage.ResultHi := LPosition.Line;
end;

procedure TCustomBCEditor.EMEmptyUndoBuffer(var AMessage: TMessage);
begin
  FLines.ClearUndo();
end;

procedure TCustomBCEditor.EMFmtLines(var AMessage: TMessage);
begin
  FFmtLines := BOOL(AMessage.WParam);

  AMessage.Result := AMessage.WParam;
end;

procedure TCustomBCEditor.EMGetFirstVisible(var AMessage: TMessage);
begin
  if (FTopRow < FRows.Count) then
    AMessage.Result := FRows.Items[FTopRow].Line
  else
    AMessage.Result := FLines.Count - 1;
end;

procedure TCustomBCEditor.EMGetHandle(var AMessage: TMessage);
begin
  AMessage.Result := 0;
end;

procedure TCustomBCEditor.EMGetIMEStatus(var AMessage: TMessage);
begin
  if (AMessage.WParam <> EMSIS_COMPOSITIONSTRING) then
    AMessage.Result := 0
  else
    AMessage.Result := FIMEStatus;
end;

procedure TCustomBCEditor.EMGetLine(var AMessage: TMessage);
var
  LLine: Integer;
begin
  if (AMessage.WParam > 0) then
    LLine := Integer(AMessage.WParam)
  else if (FTopRow >= FRows.Count) then
    LLine := -1
  else
    LLine := FRows.Items[FTopRow].Line;
  if ((LLine < 0) or (AMessage.LParam = 0) or (Word(Pointer(AMessage.LParam)^) >= Length(FLines.Items[LLine].Text))) then
    AMessage.Result := 0
  else
    StrPCopy(PChar(AMessage.LParam), FLines.Items[LLine].Text);
end;

procedure TCustomBCEditor.EMGetLineCount(var AMessage: TMessage);
begin
  if (FLines.Count = 0) then
    AMessage.Result := 1
  else
    AMessage.Result := LPARAM(FLines.Count);
end;

procedure TCustomBCEditor.EMGetModify(var AMessage: TMessage);
begin
  AMessage.Result := LRESULT(Modified);
end;

procedure TCustomBCEditor.EMGetRect(var AMessage: TMessage);
begin
  if (AMessage.LParam <> 0) then
    Windows.PRect(AMessage.LParam)^ := FMetrics.TextRect;
end;

procedure TCustomBCEditor.EMGetSel(var AMessage: TMessage);
var
  LSelStart: Integer;
  LSelLength: Integer;
begin
  LSelStart := SelStart;
  LSelLength := SelLength;

  if (AMessage.WParam <> 0) then
    PDWORD(AMessage.WParam)^ := LSelStart;
  if (AMessage.WParam <> 0) then
    PDWORD(AMessage.WParam)^ := LSelStart + SelLength;

  if (LSelStart + LSelLength > 65535) then
    AMessage.Result := -1
  else
  begin
    AMessage.ResultLo := LSelStart;
    AMessage.ResultHi := LSelStart + LSelLength;
  end;
end;

procedure TCustomBCEditor.EMGetThumb(var AMessage: TMessage);
begin
  AMessage.Result := FTopRow * FLineHeight;
end;

procedure TCustomBCEditor.EMLineFromChar(var AMessage: TMessage);
begin
  if (Integer(AMessage.WParam) <> -1) then
    if (AMessage.WParam <= WPARAM(FLines.TextLength)) then
      AMessage.Result := FLines.PositionOf(Integer(AMessage.WParam)).Line
    else
      AMessage.Result := 0
  else if (not FLines.SelArea.IsEmpty()) then
    AMessage.Result := FLines.SelArea.BeginPosition.Line
  else
    AMessage.Result := Min(Max(0, FLines.Count - 1), FLines.CaretPosition.Line);
end;

procedure TCustomBCEditor.EMLineIndex(var AMessage: TMessage);
var
  LLine: Integer;
begin
  if (Integer(AMessage.WParam) = - 1) then
    LLine := FLines.CaretPosition.Line
  else
    LLine := Integer(AMessage.WParam);

  AMessage.Result := LRESULT(FLines.CharIndexOf(FLines.BOLPosition[LLine]));
end;

procedure TCustomBCEditor.EMLineLength(var AMessage: TMessage);
var
  LLine: Integer;
begin
  if (Integer(AMessage.WParam) = -1) then
    AMessage.Result := FLines.CharIndexOf(FLines.SelArea.BeginPosition) - FLines.CharIndexOf(FLines.BOLPosition[FLines.SelArea.BeginPosition.Line])
  else if (Integer(AMessage.WParam) < FLines.TextLength) then
    AMessage.Result := 0
  else
  begin
    LLine := FLines.PositionOf(AMessage.WParam).Line;
    if (LLine < FLines.Count) then
      AMessage.Result := Length(FLines.Items[LLine].Text)
    else
      AMessage.Result := 0;
  end;
end;

procedure TCustomBCEditor.EMLineScroll(var AMessage: TMessage);
begin
  AMessage.Result := LRESULT(TRUE);
end;

procedure TCustomBCEditor.EMPosFromChar(var AMessage: TMessage);
var
  LClient: TPoint;
begin
  if (AMessage.WParam >= WPARAM(FLines.TextLength)) then
    AMessage.Result := -1
  else
  begin
    LClient := RowsToClient(LinesToRows(FLines.PositionOf(AMessage.WParam)));
    AMessage.ResultLo := LClient.X;
    AMessage.ResultHi := LClient.Y;
  end;
end;

procedure TCustomBCEditor.EMReplaceSel(var AMessage: TMessage);
begin
  SelText := StrPas(PChar(AMessage.LParam));
  if (not BOOL(AMessage.WParam)) then
    ClearUndo();
end;

procedure TCustomBCEditor.EMScroll(var AMessage: TMessage);
begin
  case (AMessage.WParam) of
    SB_LINEDOWN: DoUpOrDown(1, False);
    SB_LINEUP: DoUpOrDown(-1, False);
    SB_PAGEDOWN: DoUpOrDown(FVisibleRows, False);
    SB_PAGEUP: DoUpOrDown(- FVisibleRows, False);
  end;
end;

procedure TCustomBCEditor.EMScrollCaret(var AMessage: TMessage);
begin
  ScrollToPosition(FLines.CaretPosition);
end;

procedure TCustomBCEditor.EMSetIMEStatus(var AMessage: TMessage);
begin
  if (AMessage.WParam <> EMSIS_COMPOSITIONSTRING) then
    AMessage.Result := 0
  else
  begin
    AMessage.Result := FIMEStatus;
    FIMEStatus := AMessage.LParam;
  end;
end;

procedure TCustomBCEditor.EMSetModify(var AMessage: TMessage);
begin
  Modified := BOOL(AMessage.WParam);
end;

procedure TCustomBCEditor.EMSetReadOnly(var AMessage: TMessage);
begin
  ReadOnly := BOOL(AMessage.WParam);
  AMessage.Result := LRESULT(TRUE);
end;

procedure TCustomBCEditor.EMSetSel(var AMessage: TMessage);
var
  LSelArea: TBCEditorLinesArea;
begin
  if (AMessage.wParam = WPARAM(-1)) then
    SelLength := 0
  else if (AMessage.lParam = LPARAM(-1)) then
    SelectAll()
  else
  begin
    LSelArea.BeginPosition := FLines.PositionOf(Integer(AMessage.WParam));
    LSelArea.EndPosition := FLines.PositionOf(Integer(AMessage.LParam), LSelArea.BeginPosition);
    ProcessCommand(ecSel, TBCEditorCommandDataSelection.Create(LSelArea));
  end;
end;

procedure TCustomBCEditor.EMSetTabStop(var AMessage: TMessage);
type
  PUNIT = ^UINT;
begin
  if (AMessage.WParam <> 1) then
    AMessage.Result := LRESULT(FALSE)
  else
  begin
    FTabs.Width := PUNIT(AMessage.LParam)^;
    AMessage.Result := LRESULT(TRUE);
  end;
end;

procedure TCustomBCEditor.EMUndo(var AMessage: TMessage);
begin
  AMessage.Result := LRESULT(CanUndo);
  Undo();
end;

procedure TCustomBCEditor.EndUndoBlock();
begin
  FLines.EndUpdate();
end;

procedure TCustomBCEditor.EndUpdate();
begin
  Dec(FUpdateCount);
  if (FUpdateCount = 0) then SetUpdateState(False);
end;

procedure TCustomBCEditor.ExpandCodeFoldingLevel(const AFirstLevel: Integer; const ALastLevel: Integer);
var
  LFirstLine: Integer;
  LLastLine: Integer;
  LLevel: Integer;
  LLine: Integer;
  LRange: TBCEditorCodeFoldingRanges.TRange;
  LRangeLevel: Integer;
begin
  if (not FLines.SelArea.IsEmpty()) then
  begin
    LFirstLine := FLines.SelArea.BeginPosition.Line;
    LLastLine := FLines.SelArea.EndPosition.Line;
  end
  else
  begin
    LFirstLine := 0;
    LLastLine := FLines.Count - 1;
  end;

  BeginUpdate();

  LLevel := -1;
  for LLine := LFirstLine to LLastLine do
  begin
    LRange := TBCEditorCodeFoldingRanges.TRange(FLines.Items[LLine].CodeFolding.BeginRange);
    if (Assigned(LRange)) then
    begin
      if LLevel = -1 then
        LLevel := LRange.FoldRangeLevel;
      LRangeLevel := LRange.FoldRangeLevel - LLevel;
      if ((AFirstLevel <= LRangeLevel) and (LRangeLevel <= ALastLevel)
        and LRange.Collapsed) then
        ExpandCodeFoldingRange(LRange);
    end;
  end;

  EndUpdate();
end;

function TCustomBCEditor.ExpandCodeFoldingLines(const AFirstLine: Integer = -1; const ALastLine: Integer = -1): Integer;
var
  LFirstLine: Integer;
  LLastLine: Integer;
  LLine: Integer;
  LRange: TBCEditorCodeFoldingRanges.TRange;
begin
  if (AFirstLine >= 0) then
    LFirstLine := AFirstLine
  else
    LFirstLine := 0;
  if (ALastLine >= -1) then
    LLastLine := ALastLine
  else if (AFirstLine >= 0) then
    LLastLine := AFirstLine
  else
    LLastLine := FLines.Count - 1;

  Result := 0;
  for LLine := LFirstLine to LLastLine do
  begin
    LRange := TBCEditorCodeFoldingRanges.TRange(FLines.Items[LLine].CodeFolding.BeginRange);
    if (Assigned(LRange) and LRange.Collapsed) then
    begin
      ExpandCodeFoldingRange(LRange);
      Inc(Result);
    end;
  end;
end;

procedure TCustomBCEditor.ExpandCodeFoldingRange(const ARange: TBCEditorCodeFoldingRanges.TRange);
var
  LLine: Integer;
begin
  if (ARange.Collapsed) then
  begin
    ARange.Collapsed := False;
    ARange.SetParentCollapsedOfSubCodeFoldingRanges(False, ARange.FoldRangeLevel);

    for LLine := ARange.BeginLine + 1 to ARange.EndLine do
      InsertLineIntoRows(LLine, False);

    InvalidateText(True);
    InvalidateScrollBars();
  end;
end;

function TCustomBCEditor.ExecuteAction(Action: TBasicAction): Boolean;
begin
  Result := True;

  if (Action is TEditCut) then
    ProcessCommand(ecCutToClipboard)
  else if (Action is TEditCopy) then
    ProcessCommand(ecCopyToClipboard)
  else if (Action is TEditPaste) then
    ProcessCommand(ecPasteFromClipboard)
  else if (Action is TEditDelete) then
    ProcessCommand(ecBackspace)
  else if (Action is TEditSelectAll) then
    ProcessCommand(ecSelectAll)
  else if (Action is TEditUndo) then
    ProcessCommand(ecUndo)
  else if (Action is TSearchFindFirst) then
    ProcessCommand(ecShowFind)
  else if (Action is TSearchFindNext) then
    ProcessCommand(ecFindNext)
  else if (Action is TSearchReplace) then
    ProcessCommand(ecShowReplace)
  else
    Result := inherited;
end;

procedure TCustomBCEditor.ExportToHTML(const AFileName: string; const ACharSet: string = '';
  AEncoding: TEncoding = nil);
var
  LFileStream: TFileStream;
begin
  LFileStream := TFileStream.Create(AFileName, fmCreate);
  try
    ExportToHTML(LFileStream, ACharSet, AEncoding);
  finally
    LFileStream.Free;
  end;
end;

procedure TCustomBCEditor.ExportToHTML(AStream: TStream; const ACharSet: string = '';
  AEncoding: TEncoding = nil);
begin
  with TBCEditorExportHTML.Create(FLines, FHighlighter, Font, FTabs.Width, ACharSet) do
  try
    SaveToStream(AStream, AEncoding);
  finally
    Free;
  end;
end;

procedure TCustomBCEditor.FindDialogClose(Sender: TObject);
begin
  HideSelection := FHideSelectionBeforeSearch;
end;

procedure TCustomBCEditor.FindDialogFind(Sender: TObject);
var
  LOptions: TBCEditorFindOptions;
begin
  LOptions := LOptions - [foRegExpr];
  if (frDown in TFindDialog(Sender).Options) then
    LOptions := LOptions - [foBackwards]
  else
    LOptions := LOptions + [foBackwards];
  if (frMatchCase in TFindDialog(Sender).Options) then
    LOptions := LOptions + [foCaseSensitive]
  else
    LOptions := LOptions - [foCaseSensitive];
  LOptions := LOptions - [foEntireScope];
  if (FLines.SelArea.IsEmpty()) then
    LOptions := LOptions - [foSelection]
  else
    LOptions := LOptions + [foSelection];
  if (frWholeWord in TFindDialog(Sender).Options) then
    LOptions := LOptions + [foWholeWordsOnly]
  else
    LOptions := LOptions - [foWholeWordsOnly];

  FLastSearch := lsFind;
  FLastSearchData := TBCEditorCommandDataFind.Create(TFindDialog(Sender).FindText, LOptions);
  ProcessCommand(ecFindFirst, FLastSearchData);
end;

procedure TCustomBCEditor.FindExecuted(const AData: Pointer);
var
  LHandle: THandle;
  LSearchResult: TBCEditorLines.TSearchResult;
begin
  LSearchResult := TBCEditorLines.PSearchResult(AData)^;

  if ((LSearchResult.Area <> InvalidLinesArea)
    and (FFindState = fsWrappedAround)
    and not AskSearchWrapAround(AData)) then
    LSearchResult.Area := InvalidLinesArea;

  if ((LSearchResult.Area = InvalidLinesArea)
    and (LSearchResult.ErrorMessage = '')) then
    LSearchResult.ErrorMessage := Format(SBCEditorSearchNotFound, [PBCEditorCommandDataFind(FLastSearchData)^.Pattern]);

  if (LSearchResult.Area <> InvalidLinesArea) then
  begin
    Include(FState, esCenterCaret);
    try
      SetSelArea(LSearchResult.Area, LSearchResult.Backwards);
    finally
      Exclude(FState, esCenterCaret);
    end;
  end;
  UpdateCursor();

  if ((LSearchResult.Area = InvalidLinesArea)
    and not (foEntireScope in PBCEditorCommandDataFind(FLastSearchData)^.Options)
    and (not LSearchResult.Backwards and (FFindArea.BeginPosition > FLines.BOFPosition)
      or LSearchResult.Backwards and (FFindArea.EndPosition < FLines.EOFPosition))
    and (FFindState = fsRequested)) then
    PostMessage(WindowHandle, UM_FIND_WRAPAROUND, 0, 0)
  else
  begin
    if ((LSearchResult.Area <> InvalidLinesArea)
      or (FFindState = fsRequested)) then
      if (Assigned(FOnFindExecuted)) then
        FOnFindExecuted(Self, LSearchResult.ErrorMessage)
      else if (LSearchResult.ErrorMessage <> '') then
      begin
        if (Assigned(FFindDialog)) then
          LHandle := FFindDialog.Handle
        else
          LHandle := WindowHandle;
        MessageBox(LHandle, PChar(LSearchResult.ErrorMessage), PChar(SBCEditorMessageInformation), MB_ICONINFORMATION or MB_OK);
      end;

    if ((eoHighlightAllFoundTexts in FOptions)
      and (LSearchResult.Area <> InvalidLinesArea)) then
    begin
      if (FFindState in [fsRequested, fsWrappedAround]) then
        PostMessage(WindowHandle, UM_FIND_ALLAREAS, 0, 0)
      else if (FFindState = fsAllAreas) then
      begin
        Include(FState, esHighlightSearchAllAreas);
        InvalidateText();
      end;
    end;
  end;
end;

procedure TCustomBCEditor.FontChanged(ASender: TObject);
begin
  Include(FState, esFontChanged);
  if (FWordWrap) then
    InvalidateRows();
  InvalidateScrollBars();
  InvalidateClient();
end;

function TCustomBCEditor.GetBookmark(const AIndex: Integer; var ALinesPosition: TBCEditorLinesPosition): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  LIndex := FLines.Bookmarks.IndexOfIndex(AIndex);
  if (LIndex >= 0) then
  begin
    ALinesPosition := FLines.Bookmarks[LIndex].Pos;
    Result := True;
  end;
end;

function TCustomBCEditor.GetCanPaste(): Boolean;
begin
  Result := not FReadOnly and (IsClipboardFormatAvailable(CF_TEXT) or IsClipboardFormatAvailable(CF_UNICODETEXT));
end;

function TCustomBCEditor.GetCanRedo(): Boolean;
begin
  Result := not FReadOnly and FLines.CanRedo;
end;

function TCustomBCEditor.GetCanUndo(): Boolean;
begin
  Result := not FReadOnly and FLines.CanUndo;
end;

function TCustomBCEditor.GetCaretPos(): TPoint;
begin
  Result := FLines.CaretPosition;
end;

function TCustomBCEditor.GetCharAt(APos: TPoint): Char;
begin
  Result := FLines.Char[APos];
end;

function TCustomBCEditor.GetCursor(): TCursor;
begin
  Result := inherited Cursor;
end;

function TCustomBCEditor.GetFindTokenData(const ARow: Integer; var ALeft: Integer;
  out ABeginRange: TBCEditorHighlighter.TRange;
  out AText: PChar; out ALength, AChar: Integer; out AColumn: Integer): Boolean;
var
  LIndex: Integer;
begin
  Result := ARow < FRows.Count;
  if (Result) then
    if (Assigned(FRows.Items[ARow].Parts)) then
    begin
      LIndex := 0;
      while ((LIndex + 1 < Length(FRows.Items[ARow].Parts))
        and (ALeft > FRows.Items[ARow].Parts[LIndex + 1].Left)) do
        Inc(LIndex);
      ALeft := FRows.Items[ARow].Parts[LIndex].Left;
      ABeginRange := FRows.Items[ARow].Parts[LIndex].BeginRange;
      AText := @FLines.Items[FRows.Items[ARow].Line].Text[1 + FRows.Items[ARow].Char + FRows.Items[ARow].Parts[LIndex].Char];
      ALength := FRows.Items[ARow].Length - FRows.Items[ARow].Parts[LIndex].Char;
      AChar := FRows.Items[ARow].Parts[LIndex].Char;
      AColumn := FRows.Items[ARow].Parts[LIndex].Column;
    end
    else if (FLines.Items[FRows.Items[ARow].Line].Text <> '') then
    begin
      ALeft := 0;
      ABeginRange := FRows.Items[ARow].BeginRange;
      AText := @FLines.Items[FRows.Items[ARow].Line].Text[1 + FRows.Items[ARow].Char];
      ALength := FRows.Items[ARow].Length;
      AChar := 0;
      AColumn := 0;
    end
    else
    begin
      ALeft := 0;
      ABeginRange := nil;
      AText := nil;
      ALength := 0;
      AChar := 0;
      AColumn := 0;
    end;
end;

function TCustomBCEditor.GetLeadingExpandedLength(const AStr: string; const ABorder: Integer = 0): Integer;
var
  LChar: PChar;
  LLength: Integer;
begin
  Result := 0;
  LChar := PChar(AStr);
  if ABorder > 0 then
    LLength := Min(PInteger(LChar - 2)^, ABorder)
  else
    LLength := PInteger(LChar - 2)^;
  while LLength > 0 do
  begin
    if LChar^ = BCEDITOR_TAB_CHAR then
      Inc(Result, FTabs.Width - (Result mod FTabs.Width))
    else
    if (CharInSet(LChar^, [BCEDITOR_NONE_CHAR, BCEDITOR_SPACE_CHAR])) then
      Inc(Result)
    else
      Exit;
    Inc(LChar);
    Dec(LLength);
  end;
end;

function TCustomBCEditor.GetLineIndentLevel(const ALine: Integer): Integer;
var
  LLineEndPos: PChar;
  LLinePos: PChar;
begin
  Assert((0 <= ALine) and (ALine < FLines.Count));

  Result := 0;
  if (FLines.Items[ALine].Text <> '') then
  begin
    LLinePos := @FLines.Items[ALine].Text[1];
    LLineEndPos := @FLines.Items[ALine].Text[Length(FLines.Items[ALine].Text)];
    while ((LLinePos <= LLineEndPos) and CharInSet(LLinePos^, [BCEDITOR_NONE_CHAR, BCEDITOR_TAB_CHAR, BCEDITOR_SPACE_CHAR])) do
    begin
      if (LLinePos^ <> BCEDITOR_TAB_CHAR) then
        Inc(Result)
      else
        Inc(Result, FTabs.Width - Result mod FTabs.Width);
      Inc(LLinePos);
    end;
  end;
end;

function TCustomBCEditor.GetMarks(): TBCEditorLines.TMarkList;
begin
  Result := FLines.Marks;
end;

function TCustomBCEditor.GetModified(): Boolean;
begin
  Result := FLines.Modified;
end;

function TCustomBCEditor.GetLines(): TStrings;
begin
  Result := FLines;
end;

function TCustomBCEditor.GetSearchResultCount: Integer;
begin
  Result := FLines.FoundAreas.Count;
end;

function TCustomBCEditor.GetSelLength(): Integer;
begin
  Result := FLines.CharIndexOf(FLines.SelArea.EndPosition, FLines.SelArea.BeginPosition);
end;

function TCustomBCEditor.GetSelStart(): Integer;
begin
  Result := FLines.CharIndexOf(FLines.SelArea.BeginPosition);
end;

function TCustomBCEditor.GetSelText(): string;
begin
  Result := FLines.TextIn[FLines.SelArea];
end;

function TCustomBCEditor.GetText(): string;
begin
  Result := FLines.Text;
end;

function TCustomBCEditor.GetUndoOptions(): TBCEditorUndoOptions;
begin
  Result := [];
  if (loUndoGrouped in FLines.Options) then
    Result := Result + [uoGroupUndo];
  if (loUndoAfterLoad in FLines.Options) then
    Result := Result + [uoUndoAfterLoad];
  if (loUndoAfterSave in FLines.Options) then
    Result := Result + [uoUndoAfterSave];
end;

function TCustomBCEditor.GetWordAt(ALinesPos: TPoint): string;
var
  LArea: TBCEditorLinesArea;
begin
  LArea := FLines.WordArea[ALinesPos];
  if (LArea = InvalidLinesArea) then
    Result := ''
  else
    Result := FLines.TextIn[LArea];
end;

function TCustomBCEditor.GiveFeedback(dwEffect: Longint): HResult;
begin
  Result := DRAGDROP_S_USEDEFAULTCURSORS;
end;

procedure TCustomBCEditor.GotoBookmark(const AIndex: Integer);
var
  LNewCaretPosition: TBCEditorLinesPosition;
begin
  if (GetBookmark(AIndex, LNewCaretPosition)) then
  begin
    Include(FState, esCenterCaret);
    try
      FLines.CaretPosition := LNewCaretPosition;
    finally
      Exclude(FState, esCenterCaret);
    end;
  end;
end;

procedure TCustomBCEditor.GotoNextBookmark;
var
  LIndex: Integer;
  LMark: TBCEditorLines.TMark;
begin
  for LIndex := 0 to FLines.Bookmarks.Count - 1 do
  begin
    LMark := FLines.Bookmarks.Items[LIndex];
    if (LMark.Pos > FLines.CaretPosition) then
    begin
      GotoBookmark(LMark.Index);
      Exit;
    end;
  end;
  if FLines.Bookmarks.Count > 0 then
    GotoBookmark(FLines.Bookmarks.Items[0].Index);
end;

procedure TCustomBCEditor.GotoPreviousBookmark;
var
  LIndex: Integer;
  LMark: TBCEditorLines.TMark;
begin
  for LIndex := FLines.Bookmarks.Count - 1 downto 0 do
  begin
    LMark := FLines.Bookmarks.Items[LIndex];
    if (LMark.Pos < FLines.CaretPosition) then
    begin
      GotoBookmark(LMark.Index);
      Exit;
    end;
  end;
  if FLines.Bookmarks.Count > 0 then
    GotoBookmark(FLines.Bookmarks.Items[FLines.Bookmarks.Count - 1].Index);
end;

procedure TCustomBCEditor.HighlighterChanged(ASender: TObject);
var
  LElement: TBCEditorHighlighter.PElement;
begin
  LElement := FHighlighter.Colors.GetElement(BCEDITOR_ATTRIBUTE_ELEMENT_EDITOR);
  if (Assigned(LElement) and (LElement^.Foreground <> clNone)) then
    Font.Color := LElement^.Foreground
  else
    Font.Color := clWindowText;
  if (Assigned(LElement) and (LElement^.Background <> clNone)) then
    Color := LElement^.Background
  else
    Color := clWindow;

  FLines.TerminateJob();
  InvalidateRows();
  InvalidateMatchingPair();

  Include(FState, esHighlighterChanged);
end;

function TCustomBCEditor.IndentText(const IndentCount: Integer): string;
begin
  if (not (eoAutoIndent in FOptions)) then
    Result := ''
  else if (toTabsToSpaces in FTabs.Options) then
    Result := StringOfChar(BCEDITOR_SPACE_CHAR, IndentCount)
  else
  begin
    Result := StringOfChar(BCEDITOR_TAB_CHAR, IndentCount div FTabs.Width);
    Result := Result + StringOfChar(BCEDITOR_SPACE_CHAR, IndentCount mod FTabs.Width);
  end;
end;

procedure TCustomBCEditor.InsertLine();
begin
  if (not FLines.SelArea.IsEmpty()) then
    SelText := FLines.LineBreak
  else
    FLines.InsertText(FLines.CaretPosition, FLines.LineBreak);
end;

procedure TCustomBCEditor.InsertLineIntoRows(const ALine: Integer; const ANewLine: Boolean);
var
  LCodeFolding: Integer;
  LInsertedRows: Integer;
  LLine: Integer;
  LRange: TBCEditorCodeFoldingRanges.TRange;
  LRow: Integer;
begin
  for LCodeFolding := 0 to FAllCodeFoldingRanges.AllCount - 1 do
  begin
    LRange := FAllCodeFoldingRanges[LCodeFolding];
    if (Assigned(LRange)
      and LRange.Collapsed
      and (LRange.BeginLine < ALine) and (ALine <= LRange.EndLine)) then
      Exit;
  end;

  LLine := ALine + 1;
  while ((LLine < FLines.Count) and (FLines.Items[LLine].FirstRow < 0)) do
    Inc(LLine);
  if (LLine < FLines.Count) then
    LRow := FLines.Items[LLine].FirstRow
  else
    LRow := FRows.Count;

  FPaintHelper.BeginDraw(Canvas.Handle);
  try
    LInsertedRows := InsertLineIntoRows(FPaintHelper, nil, ALine, LRow);
  finally
    FPaintHelper.EndDraw();
  end;

  if (not (esCaretInvalid in FState)
    and (FLines.CaretPosition.Line >= ALine)) then
  begin
    Inc(FCaretPos.Y, LInsertedRows * FLineHeight);
    UpdateCaret();
  end;

  if (ANewLine) then
    for LRow := LRow + LInsertedRows to FRows.Count - 1 do
      FRows.List[LRow].Line := FRows.List[LRow].Line + 1;
end;

function TCustomBCEditor.InsertLineIntoRows(const APaintHelper: TPaintHelper;
  const AThread: TBuildRowsThread; const ALine, ARow: Integer): Integer;
const
  CRowPartLength = 1000;
var
  LBeginRange: TBCEditorHighlighter.TRange;
  LChar: Integer;
  LColumn: Integer;
  LFlags: TRow.TFlags;
  LLine: Integer;
  LRow: Integer;
  LRowLength: Integer;
  LRowPart: TRow.TPart;
  LRowPartList: TList<TRow.TPart>;
  LRowParts: TRow.TParts;
  LRowWidth: Integer;
  LTerminated: Boolean;
  LToken: TBCEditorHighlighter.TTokenFind;
  LTokenBeginPos: PChar;
  LTokenEndPos: PChar;
  LTokenPos: PChar;
  LTokenPrevPos: PChar;
  LTokenRowBeginPos: PChar;
  LTokenRowText: string;
  LTokenRowWidth: Integer;
  LTokenWidth: Integer;
begin
  LTerminated := False;
  LRowPart.Char := 0;
  LRowPartList := nil;
  if (not FHighlighter.FindFirstToken(FLines.Items[ALine].BeginRange,
    PChar(FLines.Items[ALine].Text), Length(FLines.Items[ALine].Text), 0,
    LToken)) then
  begin
    FRows.Insert(ARow, [rfFirstRowOfLine, rfLastRowOfLine], ALine, 0,
      0, 0, 0, FLines.Items[ALine].BeginRange, nil);
    Result := 1;
  end
  else
  begin
    if (not FWordWrap) then
    begin
      LColumn := 0;
      LRowWidth := 0;
      repeat
        // Long lines will be splitted into multiple parts to proceed the
        // painting faster.
        if (LToken.Char - LRowPart.Char > CRowPartLength) then
        begin
          if (not Assigned(LRowPartList)) then
          begin
            LRowPartList := TList<TRow.TPart>.Create();
            LRowPart.BeginRange := FLines.Items[ALine].BeginRange;
            LRowPart.Column := 0;
            LRowPart.Left := 0;
            LRowPartList.Add(LRowPart);
          end
          else
            LRowPartList.Add(LRowPart);

          LRowPart.BeginRange := LToken.Range;
          LRowPart.Char := LToken.Char;
          LRowPart.Column := LColumn;
          LRowPart.Left := LRowWidth;

          LTerminated := Assigned(AThread) and AThread.Terminated;
        end;

        Inc(LRowWidth, TokenWidth(APaintHelper, ALine, LToken.Text, LToken.Length, LColumn, @LToken));
        Inc(LColumn, TokenColumns(LToken.Text, LToken.Length, LColumn));
      until (LTerminated or not FHighlighter.FindNextToken(LToken));

      if (LTerminated) then
        Result := 0
      else
      begin
        if (not Assigned(LRowPartList)) then
          FRows.Insert(ARow, [rfFirstRowOfLine, rfLastRowOfLine], ALine, 0,
            Length(FLines.Items[ALine].Text), LColumn, LRowWidth, FLines.Items[ALine].BeginRange, nil)
        else
        begin
          LRowPartList.Add(LRowPart);
          SetLength(LRowParts, LRowPartList.Count);
          Move(LRowPartList.List[0], LRowParts[0], LRowPartList.Count * SizeOf(LRowParts[0]));
          FRows.Insert(ARow, [rfFirstRowOfLine, rfLastRowOfLine], ALine, 0,
            Length(FLines.Items[ALine].Text), LColumn, LRowWidth, FLines.Items[ALine].BeginRange, LRowParts);
        end;
        Result := 1;
      end;

      if (Assigned(LRowPartList)) then
        LRowPartList.Free();
    end
    else
    begin
      LRow := ARow;
      LLine := FRows.Items[LRow].Line;
      LFlags := [rfFirstRowOfLine];
      LRowWidth := 0;
      LRowLength := 0;
      LColumn := 0;
      LChar := 0;
      LBeginRange := FLines.Items[ALine].BeginRange;
      repeat
        LTokenWidth := TokenWidth(APaintHelper, LLine, LToken.Text, LToken.Length, LColumn, @LToken);

        if (LRowWidth + LTokenWidth <= FMetrics.TextRect.Width) then
        begin
          { no row break in token }
          Inc(LRowLength, LToken.Length);
          Inc(LRowWidth, LTokenWidth);
          Inc(LColumn, TokenColumns(LToken.Text, LToken.Length, LColumn));
        end
        else if (LRowLength > 0) then
        begin
          { row break before token }
          FRows.Insert(LRow, LFlags, ALine, LChar, LRowLength, LColumn, LRowWidth, LBeginRange, nil);
          Exclude(LFlags, rfFirstRowOfLine);
          Inc(LChar, LRowLength);
          Inc(LRow);

          LBeginRange := LToken.Range;
          LRowLength := LToken.Length;
          LRowWidth := LTokenWidth;
          LColumn := TokenColumns(LToken.Text, LToken.Length, LColumn);

          LTerminated := Assigned(AThread) and AThread.Terminated;
        end
        else
        begin
          { row break inside token }
          LTokenBeginPos := LToken.Text;
          LTokenPos := LTokenBeginPos;
          LTokenEndPos := @LTokenPos[LToken.Length];

          repeat
            LTokenRowBeginPos := LTokenPos;

            Inc(LTokenPos);

            repeat
              LTokenPrevPos := LTokenPos;

              LTokenRowWidth := TokenWidth(APaintHelper, LLine, LToken.Text, LTokenPos - LTokenRowBeginPos, LColumn, @LToken);

              if (LTokenRowWidth < FMetrics.TextRect.Width) then
                repeat
                  Inc(LTokenPos);
                until ((LTokenPos > LTokenEndPos)
                  or (Char((LTokenPos - 1)^).GetUnicodeCategory() <> TUnicodeCategory.ucNonSpacingMark) or IsCombiningDiacriticalMark((LTokenPos - 1)^)
                    and not (Char(LTokenPos^).GetUnicodeCategory in [TUnicodeCategory.ucCombiningMark, TUnicodeCategory.ucNonSpacingMark]));
            until ((LTokenPos > LTokenEndPos) or (LTokenRowWidth >= FMetrics.TextRect.Width));

            if (LTokenRowWidth >= FMetrics.TextRect.Width) then
            begin
              LTokenPos := LTokenPrevPos;

              LRowLength := LTokenPos - LTokenRowBeginPos - 1;
              FRows.Insert(LRow, LFlags, ALine, LChar, LRowLength, LColumn, LTokenRowWidth, LBeginRange, nil);
              Exclude(LFlags, rfFirstRowOfLine);
              Inc(LChar, LRowLength);
              Inc(LRow);

              LBeginRange := LToken.Range;
              LRowLength := 0;
              LRowWidth := 0;
              LColumn := 0;
            end
            else
            begin
              LRowLength := LTokenPos - LTokenRowBeginPos;
              LRowWidth := LTokenRowWidth;
              SetString(LTokenRowText, PChar(@LToken.Text[LTokenRowBeginPos - LTokenBeginPos]), LRowLength);
              LColumn := TokenColumns(PChar(LTokenRowText), Length(LTokenRowText), LColumn);
            end;
          until ((LTokenPos > LTokenEndPos) or (LTokenRowWidth < FMetrics.TextRect.Width));

          LTerminated := Assigned(AThread) and AThread.Terminated;
        end;
      until (LTerminated or not FHighlighter.FindNextToken(LToken));

      if (not LTerminated and (LRowLength > 0)) then
      begin
        FRows.Insert(LRow, LFlags + [rfLastRowOfLine], ALine, LChar, LRowLength, LColumn, LRowWidth, LBeginRange, nil);
        Inc(LRow);
      end;
      Result := LRow - ARow;
    end;
    FHighlighter.FindClose(LToken);
  end;

  if (LTerminated) then
  begin
    for LRow := ARow to ARow + Result - 1 do
      FRows.Delete(ARow);
  end
  else
  begin
    FLines.SetRow(ALine, ARow, Result);
    for LLine := ALine + 1 to FLines.Count - 1 do
      if (FLines.Items[LLine].FirstRow >= 0) then
        FLines.SetRow(LLine, FLines.Items[LLine].FirstRow + Result, FLines.Items[LLine].RowCount);
    Inc(FLastLineInBuiltRows);
  end;
end;

procedure TCustomBCEditor.InvalidateCaret();
begin
  FRows.FCaretPosition := InvalidRowsPosition;
  FCaretPos := InvalidPos;
  SetInsertPos(InvalidPos);
  Include(FState, esCaretInvalid);

  if ((UpdateCount = 0) and not (esPainting in FState) and (FRows.Count > 0)) then
    UpdateCaret();

  if ((eoHighlightActiveLine in FOptions)
    and (FLines.CaretPosition.Line <> FOldActiveLine)) then
  begin
    InvalidateText(FOldActiveLine, True);
    InvalidateText(FLines.CaretPosition.Line, True);
  end;
end;

procedure TCustomBCEditor.InvalidateClient();
begin
  InvalidateRect(FMetrics.ClientRect);
  InvalidateCaret();
end;

procedure TCustomBCEditor.InvalidateCodeFolding();
var
  LLine: Integer;
begin
  FAllCodeFoldingRanges.ClearAll();

  for LLine := 0 to FLines.Count - 1 do
  begin
    FLines.SetCodeFoldingBeginRange(LLine, nil);
    FLines.SetCodeFoldingEndRange(LLine, nil);
    FLines.SetCodeFoldingTreeLine(LLine, False);
  end;

  Include(FState, esCodeFoldingInvalid);

  InvalidateRect(FMetrics.CodeFoldingRect);

  if (HandleAllocated) then
    KillTimer(WindowHandle, tiCodeFolding);
end;

procedure TCustomBCEditor.InvalidateMatchingPair();
begin
  InvalidateText(FLines.MatchedPairOpenArea.BeginPosition.Line);
  InvalidateText(FLines.MatchedPairCloseArea.BeginPosition.Line);

  Include(FState, esMatchedPairInvalid);
end;

procedure TCustomBCEditor.InvalidateOverlays();
var
  LIndex: Integer;
begin
  if (not (esPainting in FState)) then
    for LIndex := 0 to FOverlays.Count - 1 do
      InvalidateText(FOverlays[LIndex].Area.BeginPosition.Line);

  FOverlays.Clear();
end;

procedure TCustomBCEditor.InvalidateRect(const ARect: TRect; const AOverlay: Boolean = False);
var
  LRect: TRect;
begin
  if (not ARect.IsEmpty()) then
  begin
    LRect := TRect.Intersect(ARect, FMetrics.ClientRect);

    if (not LRect.IsEmpty()) then
    begin
      if (DoubleBuffered and not AOverlay) then
        if (FDoubleBufferUpdateRect.IsEmpty()) then
          FDoubleBufferUpdateRect := LRect
        else
          FDoubleBufferUpdateRect.Union(LRect);
      Windows.InvalidateRect(WindowHandle, LRect, not (csOpaque in ControlStyle))
    end;
  end;
end;

procedure TCustomBCEditor.InvalidateRows();
begin
  if (Assigned(FBuildRowsThread)) then
    FBuildRowsThread.Terminate();

  FRows.Clear();
  FLastLineInBuiltRows := -1;

  Include(FState, esRowsInvalid);

  InvalidateText();

  FOldClientRect := FMetrics.ClientRect;
end;

procedure TCustomBCEditor.InvalidateScrollBars();
begin
  Include(FState, esScrollBarsInvalid);

  if (FState * [esPainting, esFontChanged, esSizeChanged, esSysFontChanged] = []) then
    PostMessage(WindowHandle, UM_UPDATE_SCROLLBARS, 0, 0);
end;

procedure TCustomBCEditor.InvalidateSyncEdit();
begin
  if (not FLines.SyncEdit and not FLines.SelArea.IsEmpty()) then
    Include(FState, esSyncEditInvalid);
end;

procedure TCustomBCEditor.InvalidateSyncEditButton();
var
  LRect: TRect;
begin
  if (FSyncEditButtonRect.IsEmpty()) then
  begin
    LRect.Left := 2 * GetSystemMetrics(SM_CXEDGE);
    LRect.Top := (LinesToRows(FLines.SelArea.EndPosition).Row - FTopRow) * FLineHeight;
    LRect.Right := LRect.Left + GetSystemMetrics(SM_CXSMICON) + 2 * GetSystemMetrics(SM_CXEDGE);
    LRect.Bottom := LRect.Top + GetSystemMetrics(SM_CYSMICON) + 2 * GetSystemMetrics(SM_CYEDGE);
    InvalidateRect(LRect);
  end
  else
    InvalidateRect(FSyncEditButtonRect);
end;

procedure TCustomBCEditor.InvalidateSyncEditOverlays();
begin
  if (FLines.SyncEdit) then
  begin
    Include(FState, esSyncEditOverlaysInvalid);
    InvalidateOverlays();
  end;
end;

procedure TCustomBCEditor.InvalidateText(const AEncloseLeftMargin: Boolean = False);
begin
  if (AEncloseLeftMargin) then
    InvalidateRect(Rect(0, FMetrics.TextRect.Top, FMetrics.TextRect.Right, FMetrics.TextRect.Bottom))
  else
    InvalidateRect(FMetrics.TextRect);
  InvalidateCaret();
end;

procedure TCustomBCEditor.InvalidateText(const ALine: Integer; const AEncloseLeftMargin: Boolean = False);
var
  LLeft: Integer;
  LRect: TRect;
  LRow: Integer;
begin
  if (FLineHeight > 0) then
  begin
    if (AEncloseLeftMargin) then
      LLeft := 0
    else
      LLeft := FMetrics.TextRect.Left;

    if ((0 <= ALine) and (ALine < FLines.Count)
      and (FLines.Items[ALine].FirstRow >= 0)) then
    begin
      for LRow := FLines.Items[ALine].FirstRow to FLines.Items[ALine].FirstRow + FLines.Items[ALine].RowCount do
      begin
        LRect := Rect(LLeft, (LRow - FTopRow) * FLineHeight, FMetrics.TextRect.Right, (LRow - FTopRow + 1) * FLineHeight);
        InvalidateRect(LRect);
      end;
    end
    else if (ALine >= FLines.Count) then
    begin
      LRect := Rect(
        LLeft, (FRows.Count - FTopRow + ALine - FLines.Count) * FLineHeight,
        FMetrics.TextRect.Right - 1, (FRows.Count - FTopRow + ALine - FLines.Count + 1) * FLineHeight - 1);
      InvalidateRect(LRect);
    end;
  end;
end;

function TCustomBCEditor.IsColorsStored(): Boolean;
begin
  Result := FColors.IsStored();
end;

function TCustomBCEditor.IsCommentChar(const AChar: Char): Boolean;
begin
  Result := Assigned(FHighlighter) and CharInSet(AChar, FHighlighter.Comments.Chars);
end;

function TCustomBCEditor.IsEmptyChar(const AChar: Char): Boolean;
begin
  Result := CharInSet(AChar, BCEDITOR_EMPTY_CHARACTERS);
end;

function TCustomBCEditor.IsCompletionProposalStored(): Boolean;
begin
  Result := FCompletionProposal.IsStored();
end;

function TCustomBCEditor.IsFontStored(): Boolean;
begin
  Result := not ParentFont
    and ((Font.Name <> DefaultFontName) or (Font.Size <> FDefaultFontSize));
end;

function TCustomBCEditor.IsLeftMarginStored(): Boolean;
begin
  Result := FLeftMargin.IsStored();
end;

function TCustomBCEditor.IsWordBreakChar(const AChar: Char): Boolean;
begin
  Result := FLines.IsWordBreakChar(AChar);
end;

procedure TCustomBCEditor.KeyDown(var AKey: Word; AShift: TShiftState);
var
  LCommand: TBCEditorCommand;
begin
  inherited;

  if (Assigned(BCEditorCommandManager)
    and BCEditorCommandManager.TryShortCutToCommand(ShortCut(AKey, AShift), LCommand)) then
  begin
    Include(FState, esKeyHandled);
    if (ProcessCommand(LCommand)) then
      AKey := 0;
  end;
end;

procedure TCustomBCEditor.KeyPress(var AKey: Char);
begin
  inherited;

  if (not (esKeyHandled in FState)
    and (AKey <> #0)
    and ProcessCommand(ecChar, TBCEditorCommandDataChar.Create(AKey))) then
  begin
    AKey := #0;

    if (FCompletionProposal.Enabled
      and not Assigned(FCompletionProposalPopup)) then
      if ((cpoAutoInvoke in FCompletionProposal.Options) and AKey.IsLetter) then
        ProcessCommand(ecShowCompletionProposal)
      else if (FCompletionProposal.Trigger.Enabled) then
        if (Pos(AKey, FCompletionProposal.Trigger.Chars) > 0) then
          SetTimer(WindowHandle, tiCompletionProposal, FCompletionProposal.Trigger.Interval, nil)
        else
          KillTimer(WindowHandle, tiCompletionProposal);
  end;

  Exclude(FState, esKeyHandled);
end;

procedure TCustomBCEditor.LeftMarginChanged(ASender: TObject);
begin
  ExpandCodeFoldingLines();
  Include(FState, esSizeChanged);
  UpdateMetrics();
  InvalidateCodeFolding();
  InvalidateScrollBars();
  InvalidateText(True);
end;

function TCustomBCEditor.LeftSpaceCount(const AText: string; AWantTabs: Boolean = False): Integer;
var
  LTextEndPos: PChar;
  LTextPos: PChar;
begin
  if ((AText = '') or not (eoAutoIndent in FOptions)) then
    Result := 0
  else
  begin
    LTextPos := @AText[1];
    LTextEndPos := @AText[Length(AText)];
    Result := 0;
    while ((LTextPos <= LTextEndPos) and (LTextPos^ <= BCEDITOR_SPACE_CHAR)) do
    begin
      if ((LTextPos^ = BCEDITOR_TAB_CHAR) and AWantTabs) then
        Inc(Result, FTabs.Width - Result mod FTabs.Width)
      else
        Inc(Result);
      Inc(LTextPos);
    end;
  end;
end;

function TCustomBCEditor.LeftTrimLength(const AText: string): Integer;
begin
  Result := 0;
  while ((Result < Length(AText)) and (AText[1 + Result] <= BCEDITOR_SPACE_CHAR)) do
    Inc(Result);
end;

procedure TCustomBCEditor.LineDeleting(ASender: TObject; const ALine: Integer);
var
  LRow: Integer;
begin
  if (ALine <= FLastLineInBuiltRows) then
  begin
    LRow := FLines.Items[ALine].FirstRow + FLines.Items[ALine].RowCount;
    for LRow := LRow to FRows.Count - 1 do
      Dec(FRows.List[LRow].Line);

    LRow := FLines.Items[ALine].FirstRow;
    if ((FTopRow <= LRow) and (LRow < FTopRow + FVisibleRows)) then
      InvalidateRect(Rect(0, LRow * FLineHeight, FMetrics.ClientRect.Width - 1, FMetrics.ClientRect.Height - 1));

    DeleteLineFromRows(ALine);

    if (ALine < FLines.Count - 1) then
      FLines.SetBeginRange(ALine + 1, FLines.Items[ALine].BeginRange);

    InvalidateCodeFolding();
    InvalidateScrollBars();
  end;

  if (UpdateCount > 0) then
    Include(FState, esTextChanged)
  else
    Change();
end;

procedure TCustomBCEditor.LineInserted(ASender: TObject; const ALine: Integer);
var
  LRow: Integer;
begin
  if ((not (rsBuilding in FRows.State) or (ALine <= FLastLineInBuiltRows) or (FLines.Count = 1))
    and not (lsLoading in FLines.State)) then
  begin
    SetLinesBeginRanges(ALine);

    InsertLineIntoRows(ALine, True);

    InvalidateCodeFolding();
    LRow := FLines.Items[ALine].FirstRow;
    if ((FTopRow <= LRow) and (LRow < FTopRow + FVisibleRows)) then
      InvalidateRect(Rect(0, LRow * FLineHeight, FMetrics.ClientRect.Width - 1, FMetrics.ClientRect.Height - 1));
    InvalidateScrollBars();
  end;

  if (UpdateCount > 0) then
    Include(FState, esTextChanged)
  else
    Change();
end;

procedure TCustomBCEditor.LinesAfterUpdate(Sender: TObject);
begin
  if (not (csReading in ComponentState)) then
    EndUpdate();
end;

procedure TCustomBCEditor.LinesBeforeUpdate(Sender: TObject);
begin
  if (not (csReading in ComponentState)) then
    BeginUpdate();
end;

procedure TCustomBCEditor.LinesCleared(ASender: TObject);
begin
  FTextPos := Point(0, 0);
  FTopRow := 0;
  InvalidateRows();
  InvalidateMatchingPair();
  InvalidateCaret();
  InvalidateScrollBars();
  InvalidateCodeFolding();
  InvalidateClient();


  Modified := True;

  if (UpdateCount > 0) then
    Include(FState, esTextChanged)
  else
    Change();
end;

procedure TCustomBCEditor.LinesChanged();
begin
  if (FLeftMargin.LineNumbers.Visible) then
  begin
    FLineNumbersWidth := 2 * GPadding + Max(2, Length(IntToStr(FLines.Count + FVisibleRows))) * FMaxDigitWidth;
    UpdateMetrics();
  end;

  InvalidateMatchingPair();
  InvalidateScrollBars();
end;

procedure TCustomBCEditor.LinesLoaded(ASender: TObject);
begin
  Loaded();
  Modified := False;
end;

procedure TCustomBCEditor.LinesSelChanged(ASender: TObject);
var
  LArea: TBCEditorLinesArea;
  LLine: Integer;
begin
  if (not FOldSelArea.IsEmpty() or not FLines.SelArea.IsEmpty()) then
  begin
    LArea := LinesArea(
      Min(FOldSelArea.BeginPosition, FLines.SelArea.BeginPosition),
      Max(FOldSelArea.BeginPosition, FLines.SelArea.BeginPosition));
    if (not LArea.IsEmpty()) then
      for LLine := LArea.BeginPosition.Line to LArea.EndPosition.Line do
        InvalidateText(LLine);
    LArea := LinesArea(
      Min(FOldSelArea.EndPosition, FLines.SelArea.EndPosition),
      Max(FOldSelArea.EndPosition, FLines.SelArea.EndPosition));
    if (not LArea.IsEmpty()) then
      for LLine := LArea.BeginPosition.Line to LArea.EndPosition.Line do
        InvalidateText(LLine);
  end;

  InvalidateSyncEditButton();
  InvalidateSyncEdit();

  if (UpdateCount > 0) then
    Include(FState, esSelChanged)
  else
    if (Assigned(FOnSelChanged)) then
      FOnSelChanged(Self);
end;

procedure TCustomBCEditor.LinesSyncEditChanged(ASender: TObject);
var
  LLine: Integer;
begin
  for LLine := FLines.SyncEditArea.BeginPosition.Line to FLines.SyncEditArea.EndPosition.Line do
    InvalidateText(LLine);
  InvalidateSyncEditButton();
  if (FLines.SyncEdit) then
    InvalidateSyncEditOverlays()
  else
    InvalidateOverlays();
end;

function TCustomBCEditor.LinesToRows(const ALinesPosition: TBCEditorLinesPosition): TBCEditorRowsPosition;
var
  LChar: Integer;
  LColumn: Integer;
  LLinePos: PChar;
  LLineEndPos: PChar;
  LRow: Integer;
begin
  if (FRows.Count = 0) then
    Result := RowsPosition(ALinesPosition.Char, ALinesPosition.Line)
  else if (ALinesPosition.Line >= FLines.Count) then
    Result := RowsPosition(ALinesPosition.Char, FRows.Count + ALinesPosition.Line - FLines.Count)
  else if (FLines.Items[ALinesPosition.Line].FirstRow < 0) then
    raise ERangeError.CreateFmt(SBCEditorLineIsNotVisible, [ALinesPosition.Line])
  else
  begin
    LRow := FLines.Items[ALinesPosition.Line].FirstRow;
    LChar := ALinesPosition.Char;
    while ((LChar >= FRows.Items[LRow].Length) and not (rfLastRowOfLine in FRows.Items[LRow].Flags)) do
    begin
      Dec(LChar, FRows.Items[LRow].Length);
      Inc(LRow);
    end;

    if (not (rfHasTabs in FRows.Items[LRow].Flags)) then
      Result := RowsPosition(ALinesPosition.Char - FRows.Items[LRow].Char, LRow)
    else
    begin
      LColumn := 0;
      LLinePos := @FLines[ALinesPosition.Line][1 + FRows.Items[LRow].Char];
      LLineEndPos := @FLines[ALinesPosition.Line][Min(1 + FRows.Items[LRow].Char + LChar, Length(FLines[ALinesPosition.Line]))];
      while (LLinePos < LLineEndPos) do
      begin
        Inc(LColumn, TokenColumns(LLinePos, 1, LColumn));
        Inc(LLinePos);
      end;
      if (Length(FLines[ALinesPosition.Line]) < LChar) then
        Inc(LColumn, LChar - Length(FLines[ALinesPosition.Line]));

      Result := RowsPosition(LColumn, LRow);
    end;
  end;
end;

procedure TCustomBCEditor.LineUpdated(ASender: TObject; const ALine: Integer);
var
  LBeginRow: Integer;
  LEndRow: Integer;
  LNewRowCount: Integer;
  LOldRowCount: Integer;
begin
  if (ALine <= FLastLineInBuiltRows) then
  begin
    SetLinesBeginRanges(ALine);

    LOldRowCount := FLines.Items[ALine].RowCount;
    UpdateLineInRows(ALine);
    LNewRowCount := FLines.Items[ALine].RowCount;

    InvalidateCodeFolding();
    LBeginRow := FLines.Items[ALine].FirstRow;
    LEndRow := LBeginRow + Max(LOldRowCount, LNewRowCount) - 1;
    if ((LBeginRow <= FTopRow + FVisibleRows) and (LEndRow >= FTopRow)) then
      if (LNewRowCount = LOldRowCount) then
        InvalidateRect(
          Rect(
            FMetrics.TextRect.Left, Max(0, LBeginRow - FTopRow) * FLineHeight,
            FMetrics.TextRect.Right, (Min(FVisibleRows, LEndRow - FTopRow) + 1) * FLineHeight))
      else
        InvalidateRect(
          Rect(
            FMetrics.TextRect.Left, Max(0, LBeginRow - FTopRow) * FLineHeight,
            FMetrics.TextRect.Right, FMetrics.TextRect.Bottom));
    InvalidateScrollBars();
  end;

  if (UpdateCount > 0) then
    Include(FState, esTextChanged)
  else
    Change();
end;

procedure TCustomBCEditor.LoadFromFile(const AFileName: string; AEncoding: TEncoding = nil);
begin
  FLines.LoadFromFile(AFileName, AEncoding);
end;

procedure TCustomBCEditor.LoadFromStream(AStream: TStream; AEncoding: TEncoding = nil);
begin
  FLines.LoadFromStream(AStream, AEncoding);
end;

procedure TCustomBCEditor.MarksChanged(ASender: TObject);
begin
  if (FLeftMargin.Marks.Visible) then
    InvalidateRect(FMetrics.MarksPanelRect);
end;

procedure TCustomBCEditor.MatchingPairScanned(const AData: Pointer);
begin
  InvalidateText(FLines.MatchedPairOpenArea.BeginPosition.Line);
  InvalidateText(FLines.MatchedPairCloseArea.BeginPosition.Line);

  Exclude(FState, esMatchedPairInvalid);
end;

procedure TCustomBCEditor.MouseDown(AButton: TMouseButton; AShift: TShiftState; X, Y: Integer);
var
  LAction: TClientJob;
begin
  KillTimer(WindowHandle, tiShowHint);
  if (Assigned(FHintWindow)) then
    FreeAndNil(FHintWindow);

  FLines.UndoGroupBreak();

  FMouseDownPoint := Point(X, Y);

  inherited;

  if (GetTickCount() < FLastDoubleClickTime + FDoubleClickTime) then
  begin
    LAction := cjMouseTrplClk;
    FLastDoubleClickTime := 0;
    Include(FState, esMouseDblClk);
  end
  else if (ssDouble in AShift) then
  begin
    LAction := cjMouseDblClk;
    FLastDoubleClickTime := GetTickCount();
    Include(FState, esMouseDblClk);
  end
  else
    LAction := cjMouseDown;

  ProcessClient(LAction, nil, nil, FMetrics.ClientRect, AButton, AShift, Point(X, Y));
end;

procedure TCustomBCEditor.MouseMove(AShift: TShiftState; X, Y: Integer);
var
  LMsg: TMsg;
begin
  if (Assigned(FHintWindow)
    and (Point(X, Y) <> FCursorPoint)) then
    FreeAndNil(FHintWindow);
  if (MouseCapture = mcText) then
    KillTimer(WindowHandle, tiScroll);

  FCursorPoint := Point(X, Y);

  inherited;

  if (PeekMessage(LMsg, WindowHandle, WM_MOUSEMOVE, WM_MOUSEMOVE, PM_NOREMOVE)
    and (KeysToShiftState(LMsg.wParam) = AShift)) then
    // Do nothing - handle this message within the next same message
  else if (FLineHeight > 0) then
  begin
    ProcessClient(cjMouseMove, nil, nil, FMetrics.ClientRect, mbLeft, AShift, FCursorPoint);

    if (not Assigned(FHintWindow)
      and (Point(X, Y) <> FLastCursorPoint)
      and (AShift * [ssLeft, ssRight, ssMiddle] = [])) then
      if (FMetrics.ClientRect.Contains(Point(X, Y))) then
        SetTimer(WindowHandle, tiShowHint, Application.HintPause, nil)
      else
        KillTimer(WindowHandle, tiShowHint);
    FLastCursorPoint := FCursorPoint;
  end;
end;

procedure TCustomBCEditor.MouseUp(AButton: TMouseButton; AShift: TShiftState; X, Y: Integer);
begin
  KillTimer(WindowHandle, tiShowHint);
  if (MouseCapture = mcText) then
    KillTimer(WindowHandle, tiScroll);

  inherited;

  ProcessClient(cjMouseUp, nil, nil, FMetrics.ClientRect, AButton, AShift, Point(X, Y));

  if (not (esScrolling in FState)) then
    MouseCapture := mcNone;
  Exclude(FState, esMouseDblClk);
end;

procedure TCustomBCEditor.MoveCaretHorizontally(const AColumns: Integer;
  const ASelect: Boolean);
var
  LLineEndPos: PChar;
  LLinePos: PChar;
  LLineTextLength: Integer;
  LNewCaretPosition: TBCEditorLinesPosition;
begin
  if (FLines.CaretPosition.Char + AColumns >= 0) then
    if (FLines.CaretPosition.Line < FLines.Count) then
    begin
      LLineTextLength := Length(FLines.Items[FLines.CaretPosition.Line].Text);

      LNewCaretPosition := LinesPosition(Max(0, FLines.CaretPosition.Char + AColumns), FLines.CaretPosition.Line);
      if (not (eoBeyondEndOfLine in FOptions) or FWordWrap) then
        LNewCaretPosition.Char := Min(LNewCaretPosition.Char, LLineTextLength);

      { Skip combined and non-spacing marks }
      if ((0 < LLineTextLength) and (LNewCaretPosition.Char < LLineTextLength)) then
      begin
        LLinePos := @FLines.Items[FLines.CaretPosition.Line].Text[1 + LNewCaretPosition.Char];
        LLineEndPos := @FLines.Items[FLines.CaretPosition.Line].Text[Length(FLines.Items[FLines.CaretPosition.Line].Text)];
        while ((LLinePos <= LLineEndPos)
          and ((LLinePos^.GetUnicodeCategory in [TUnicodeCategory.ucCombiningMark, TUnicodeCategory.ucNonSpacingMark])
            or ((LLinePos - 1)^ <> BCEDITOR_NONE_CHAR)
              and ((LLinePos - 1)^.GetUnicodeCategory = TUnicodeCategory.ucNonSpacingMark)
              and not IsCombiningDiacriticalMark((LLinePos - 1)^))) do
        begin
          Dec(LLinePos);
          Dec(LNewCaretPosition.Char);
        end;
      end;

      SetCaretPosition(LNewCaretPosition, ASelect);
    end
    else if ((eoBeyondEndOfLine in FOptions) and not FWordWrap) then
      SetCaretPosition(LinesPosition(FLines.CaretPosition.Char + AColumns, FLines.CaretPosition.Line), ASelect);
end;

function TCustomBCEditor.NextWordPosition(const ALinesPosition: TBCEditorLinesPosition): TBCEditorLinesPosition;
begin
  if (ALinesPosition.Line >= FLines.Count) then
    Result := FLines.EOFPosition
  else
  begin
    Result := Min(ALinesPosition, FLines.EOLPosition[ALinesPosition.Line]);
    if (Result.Char < Length(FLines.Items[Result.Line].Text)) then
      while ((Result.Char < Length(FLines.Items[Result.Line].Text)) and IsWordBreakChar(FLines.Char[Result])) do
        Inc(Result.Char)
    else if (Result.Line < FLines.Count - 1) then
    begin
      Result := FLines.BOLPosition[Result.Line + 1];
      while ((Result.Char + 1 < Length(FLines.Items[Result.Line].Text)) and IsWordBreakChar(FLines.Items[Result.Line].Text[Result.Char + 1])) do
        Inc(Result.Char);
    end
  end;
end;

procedure TCustomBCEditor.NotifyParent(const ANotification: Word);
begin
  if ((WindowHandle <> 0) and (FParentWnd <> 0) and not FNoParentNotify) then
    SendMessage(FParentWnd, WM_COMMAND, ANotification shl 16 + FDlgCtrlID and $FFFF, LPARAM(WindowHandle));
end;

procedure TCustomBCEditor.Paint();
begin
  PaintTo(FPaintHelper, FMetrics.ClientRect);
end;

procedure TCustomBCEditor.PaintTo(const APaintHelper: TPaintHelper; const ARect: TRect;
  const AOverlays: Boolean = True);

  procedure BuildBitmaps(const APaintVar: PPaintVar);
  var
    LBackgroundColor: TGPColor;
    LBitmap: TGPBitmap;
    LBrush: TGPSolidBrush;
    LColor: TGPColor;
    LFont: TGPFont;
    LGraphics: TGPGraphics;
    LHDC: HDC;
    LHeight: Integer;
    LIcon: TGPBitmap;
    LIconId: Integer;
    LIndex: Integer;
    LPen: TGPPen;
    LPoints: array [0 .. 2] of TGPPoint;
    LRect: TRect;
    LRectF: TGPRectF;
    LResData: HGLOBAL;
    LResInfo: HRSRC;
    LResource: Pointer;
    LStringFormat: TGPStringFormat;
    LText: string;
    LWidth: Integer;
    LY: Integer;
  begin
    LBrush := TGPSolidBrush.Create(aclTransparent);
    LFont := TGPFont.Create(GetParentForm(Self).Font.Name, FLineHeight - 2 * GPadding - 2 * GLineWidth, FontStyleRegular, UnitPixel);
    LStringFormat := TGPStringFormat.Create();
    LStringFormat.SetAlignment(StringAlignmentCenter);
    LPen := TGPPen.Create(aclTransparent, GLineWidth);
    LWidth := Min(FLineHeight, GetSystemMetrics(SM_CXSMICON));
    LHeight := LWidth;

    // Bookmarks
    LBitmap := TGPBitmap.Create(LWidth, LHeight);
    LGraphics := TGPGraphics.Create(LBitmap);
    for LIndex := 0 to BCEDITOR_BOOKMARKS - 1 do
    begin
      if (Assigned(FBookmarkBitmaps[LIndex])) then FBookmarkBitmaps[LIndex].Free();
      LBrush.SetColor(aclTransparent);
      LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
      if (LIndex < BCEDITOR_BOOKMARKS - 1) then
        LText := IntToStr(LIndex + 1)
      else
        LText := '0';
      LRectF := MakeRect(GPadding + 2 * GLineWidth + 0.0,
        GPadding + GLineWidth,
        LWidth - 2 * GPadding - 3 * GLineWidth,
        LHeight - 2 * GPadding - 3 * GLineWidth);
      LBrush.SetColor(aclBookmarkCover);
      LGraphics.FillRectangle(LBrush, LRectF);
      LRectF := MakeRect(GPadding + 2 * GLineWidth + 0.0,
        GPadding + GLineWidth - 2,
        LWidth - 2 * GPadding - 3 * GLineWidth,
        LHeight - 2 * GPadding - GLineWidth);
      LBrush.SetColor(aclBookmarkNumber);
      LGraphics.DrawString(LText, -1, LFont, LRectF, LStringFormat, LBrush);
      LPen.SetColor(aclBookmarkBorder);
      LGraphics.DrawRectangle(LPen, GPadding + GLineWidth, GPadding, FLineHeight - 2 * GPadding - 2 * GLineWidth, FLineHeight - 3 * GPadding - GLineWidth);

      LY := GPadding + 2 * GLineWidth;
      repeat
        LBrush.SetColor(aclBookmarkRingLeft);
        LGraphics.FillRectangle(LBrush, GPadding, LY, GLineWidth, GLineWidth);
        LBrush.SetColor(aclBookmarkRingMiddle);
        LGraphics.FillRectangle(LBrush, GPadding + GLineWidth, LY, GLineWidth, GLineWidth);
        LBrush.SetColor(aclBookmarkRingRight);
        LGraphics.FillRectangle(LBrush, GPadding + 2 * GLineWidth, LY, GLineWidth, GLineWidth);
        Inc(LY, 2 * GLineWidth);
      until (LY >= FLineHeight - 2 * GPadding - 2 * GLineWidth);

      FBookmarkBitmaps[LIndex] := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
    end;
    LGraphics.Free();
    LBitmap.Free();

    // CodeFoling

    if (not (csOpaque in ControlStyle)) then
      LBackgroundColor := aclTransparent
    else if (FColors.CodeFolding.Background <> clNone) then
      LBackgroundColor :=ColorRefToARGB(ColorToRGB(FColors.CodeFolding.Background))
    else
      LBackgroundColor :=ColorRefToARGB(ColorToRGB(Color));
    if (FColors.CodeFolding.Foreground <> clNone) then
      LColor := ColorRefToARGB(ColorToRGB(FColors.CodeFolding.Foreground))
    else
      LColor := ColorRefToARGB(ColorToRGB(Font.Color));

    // CodeFolding None / Collapsed / Expanded
    if (Assigned(FCodeFoldingNoneBitmap)) then FCodeFoldingNoneBitmap.Free();
    if (Assigned(FCodeFoldingCollapsedBitmap)) then FCodeFoldingCollapsedBitmap.Free();
    if (Assigned(FCodeFoldingExpandedBitmap)) then FCodeFoldingExpandedBitmap.Free();
    LBitmap := TGPBitmap.Create(LWidth, FLineHeight);
    LGraphics := TGPGraphics.Create(LBitmap);
    LPen.SetColor(LColor);
    LBrush.SetColor(LBackgroundColor);
    LGraphics.FillRectangle(LBrush, 0, 0, LWidth, FLineHeight);
    FCodeFoldingNoneBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
    LBrush.SetColor(LColor);
    LGraphics.DrawRectangle(LPen, GPadding + 2 * GLineWidth, GPadding + 2 * GLineWidth, LWidth - 2 * GPadding - 6 * GLineWidth, LHeight - 2 * GPadding - 6 * GLineWidth);
    LGraphics.DrawLine(LPen, GPadding + 4 * GLineWidth, (2 * LHeight - GLineWidth) div 4, LWidth - GPadding - 6 * GLineWidth, (2 * LHeight - GLineWidth) div 4);
    LGraphics.DrawLine(LPen, (2 * LWidth - GLineWidth) div 4, (2 * LHeight - GLineWidth) div 4 + LHeight - 2 * GPadding - 6 * GLineWidth, (2 * LWidth - GLineWidth) div 4, FLineHeight - GLineWidth);
    FCodeFoldingExpandedBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
    LGraphics.DrawLine(LPen, (2 * LWidth - GLineWidth) div 4, GPadding + 4 * GLineWidth, (2 * LWidth - GLineWidth) div 4, LHeight - GPadding - 6 * GLineWidth);
    LPen.SetColor(LBackgroundColor);
    LGraphics.DrawLine(LPen, (2 * LWidth - GLineWidth) div 4, (2 * LHeight - GLineWidth) div 4 + LHeight - 2 * GPadding - 6 * GLineWidth, (2 * LWidth - GLineWidth) div 4, FLineHeight - GLineWidth);
    FCodeFoldingCollapsedBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
    LGraphics.Free();
    LBitmap.Free();

    // CodeFolding Line / EndLine
    if (Assigned(FCodeFoldingLineBitmap)) then FCodeFoldingLineBitmap.Free();
    if (Assigned(FCodeFoldingEndLineBitmap)) then FCodeFoldingEndLineBitmap.Free();
    LBitmap := TGPBitmap.Create(LWidth, FLineHeight);
    LGraphics := TGPGraphics.Create(LBitmap);
    LPen.SetColor(LColor);
    LBrush.SetColor(LBackgroundColor);
    LGraphics.FillRectangle(LBrush, 0, 0, LWidth, FLineHeight);
    LGraphics.DrawLine(LPen, (2 * LWidth - GLineWidth) div 4, 0, (2 * LWidth - GLineWidth) div 4, FLineHeight - GLineWidth);
    FCodeFoldingLineBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
    LGraphics.DrawLine(LPen, (2 * LWidth - GLineWidth) div 4, FLineHeight - GLineWidth, LWidth - GLineWidth, FLineHeight - GLineWidth);
    FCodeFoldingEndLineBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
    LGraphics.Free();

    // InsertPos Mark
    if (Assigned(FInsertPosBitmap)) then FInsertPosBitmap.Free();
    LWidth := 3 * GLineWidth;
    LHeight := FLineHeight;
    LBitmap := TGPBitmap.Create(LWidth, LHeight);
    LGraphics := TGPGraphics.Create(LBitmap);
    LBrush.SetColor(aclTransparent);
    LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
    LBrush.SetColor(ColorRefToARGB(ColorToRGB(Font.Color)));
    LGraphics.FillRectangle(LBrush, GLineWidth, GPadding, GLineWidth, FLineHeight - GLineWidth - GPadding);
    LGraphics.SetSmoothingMode(SmoothingModeHighQuality);
    LPen.SetColor(ColorRefToARGB(ColorToRGB(Font.Color)));
    LPoints[0] := MakePoint(0, GPadding);
    LPoints[1] := MakePoint(GLineWidth, GPadding + GLineWidth);
    LPoints[2] := MakePoint(GLineWidth, GPadding);
    LGraphics.DrawPolygon(LPen, PGPPoint(@LPoints[0]), 3);
    LGraphics.FillPolygon(LBrush, PGPPoint(@LPoints[0]), 3);
    LPoints[0] := MakePoint(2 * GLineWidth - 1, GPadding);
    LPoints[1] := MakePoint(2 * GLineWidth - 1, GPadding + GLineWidth);
    LPoints[2] := MakePoint(3 * GLineWidth - 1, GPadding);
    LGraphics.DrawPolygon(LPen, PGPPoint(@LPoints[0]), 3);
    LGraphics.FillPolygon(LBrush, PGPPoint(@LPoints[0]), 3);
    LPoints[0] := MakePoint(0, FLineHeight - 1 - GPadding);
    LPoints[1] := MakePoint(GLineWidth, FLineHeight - 1 - GLineWidth - GPadding);
    LPoints[2] := MakePoint(GLineWidth, FLineHeight - 1 - GPadding);
    LGraphics.DrawPolygon(LPen, PGPPoint(@LPoints[0]), 3);
    LGraphics.FillPolygon(LBrush, PGPPoint(@LPoints[0]), 3);
    LPoints[0] := MakePoint(2 * GLineWidth - 1, FLineHeight - 1 - GPadding);
    LPoints[1] := MakePoint(2 * GLineWidth - 1, FLineHeight - 1 - GLineWidth - GPadding);
    LPoints[2] := MakePoint(3 * GLineWidth - 1, FLineHeight - 1 - GPadding);
    LGraphics.DrawPolygon(LPen, PGPPoint(@LPoints[0]), 3);
    LGraphics.FillPolygon(LBrush, PGPPoint(@LPoints[0]), 3);
    FInsertPosBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
    LGraphics.Free();


    if (esSysFontChanged in FState) then
    begin
      // Scrolling Anchor
      if (Assigned(FScrollingBitmap)) then FScrollingBitmap.Free();
      LWidth := 2 * GetSystemMetrics(SM_CXSMICON) - GetSystemMetrics(SM_CXSMICON) div 4;
      LHeight := LWidth;
      FScrollingBitmapWidth := LWidth;
      FScrollingBitmapHeight := LHeight;
      LBitmap := TGPBitmap.Create(LWidth, LHeight);
      LGraphics := TGPGraphics.Create(LBitmap);
      LBrush.SetColor(aclTransparent);
      LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
      LGraphics.SetSmoothingMode(SmoothingModeHighQuality);
      LBrush.SetColor(ColorRefToARGB(ColorToRGB(Color)));
      LGraphics.FillEllipse(LBrush, GLineWidth, GLineWidth, LWidth - GLineWidth - 1, LHeight - GLineWidth - 1);
      LPen.SetColor(ColorRefToARGB(ColorToRGB(Font.Color)));
      LGraphics.DrawEllipse(LPen, GLineWidth, GLineWidth, LWidth - GLineWidth - 1, LHeight - GLineWidth - 1);
      LBrush.SetColor(ColorRefToARGB(ColorToRGB(Font.Color)));
      LPoints[0].X := LWidth div 2;
      LPoints[0].Y := 4 * GLineWidth;
      LPoints[1].X := LWidth div 2 - 4 * GLineWidth;
      LPoints[1].Y := 8 * GLineWidth;
      LPoints[2].X := LWidth div 2 + 4 * GLineWidth;
      LPoints[2].Y := 8 * GLineWidth;
      LGraphics.DrawPolygon(LPen, PGPPoint(@LPoints[0]), 3);
      LGraphics.FillPolygon(LBrush, PGPPoint(@LPoints[0]), 3);
      LPoints[0].X := LWidth - 4 * GLineWidth;
      LPoints[0].Y := LHeight div 2;
      LPoints[1].X := LWidth - 8 * GLineWidth;
      LPoints[1].Y := LHeight div 2 - 4 * GLineWidth;
      LPoints[2].X := LWidth - 8 * GLineWidth;
      LPoints[2].Y := LHeight div 2 + 4 * GLineWidth;
      LGraphics.DrawPolygon(LPen, PGPPoint(@LPoints[0]), 3);
      LGraphics.FillPolygon(LBrush, PGPPoint(@LPoints[0]), 3);
      LPoints[0].X := LWidth div 2;
      LPoints[0].Y := LHeight - 4 * GLineWidth;
      LPoints[1].X := LWidth div 2 - 4 * GLineWidth;
      LPoints[1].Y := LHeight - 8 * GLineWidth;
      LPoints[2].X := LWidth div 2 + 4 * GLineWidth;
      LPoints[2].Y := LHeight - 8 * GLineWidth;
      LGraphics.DrawPolygon(LPen, PGPPoint(@LPoints[0]), 3);
      LGraphics.FillPolygon(LBrush, PGPPoint(@LPoints[0]), 3);
      LPoints[0].X := 4 * GLineWidth;
      LPoints[0].Y := LHeight div 2;
      LPoints[1].X := 8 * GLineWidth;
      LPoints[1].Y := LHeight div 2 - 4 * GLineWidth;
      LPoints[2].X := 8 * GLineWidth;
      LPoints[2].Y := LHeight div 2 + 4 * GLineWidth;
      LGraphics.DrawPolygon(LPen, PGPPoint(@LPoints[0]), 3);
      LGraphics.FillPolygon(LBrush, PGPPoint(@LPoints[0]), 3);
      LGraphics.DrawEllipse(LPen, LWidth div 2 - 2 * GLineWidth, LHeight div 2 - 2 * GLineWidth, 4 * GLineWidth, 4 * GLineWidth);
      LGraphics.FillEllipse(LBrush, LWidth div 2 - 2 * GLineWidth, LHeight div 2 - 2 * GLineWidth, 4 * GLineWidth, 4 * GLineWidth);
      FScrollingBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
      LGraphics.Free();


      // SyncEdit Button
      LResInfo := FindResource(HInstance, BCEDITOR_SYNCEDIT, RT_GROUP_ICON);
      LResData := LoadResource(HInstance, LResInfo);
      LResource := LockResource(LResData);
      LIconId := LookupIconIdFromDirectoryEx(LResource, TRUE, GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);
      LResInfo := FindResource(HInstance, MAKEINTRESOURCE(LIconId), RT_ICON);
      LResData := LoadResource(HInstance, LResInfo);
      LIcon := TGPBitmap.Create(CreateIconFromResourceEx(
        LockResource(LResData), SizeOfResource(HInstance, LResInfo),
        TRUE, $00030000, GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR));
      LWidth := GetSystemMetrics(SM_CXSMICON) + 2 * GetSystemMetrics(SM_CXEDGE);
      LHeight := GetSystemMetrics(SM_CYSMICON) + 2 * GetSystemMetrics(SM_CYEDGE);
      LRect := Rect(0, 0, LWidth, LHeight);
      LBrush.SetColor(aclTransparent);
      LBitmap := TGPBitmap.Create(LWidth, LHeight);
      LGraphics := TGPGraphics.Create(LBitmap);
      if (Assigned(FSyncEditButtonNormalBitmap)) then FSyncEditButtonNormalBitmap.Free();
      if (not StyleServices.Enabled) then
      begin
        LBrush.SetColor(ColorRefToARGB(ColorToRGB(clBtnFace)));
        LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
        LHDC := LGraphics.GetHDC();
        DrawEdge(LHDC, LRect, BDR_RAISEDINNER, BF_RECT);
        LGraphics.ReleaseHDC(LHDC);
      end
      else
      begin
        LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
        LHDC := LGraphics.GetHDC();
        StyleServices.DrawElement(LHDC, StyleServices.GetElementDetails(tbPushButtonNormal), LRect);
        LGraphics.ReleaseHDC(LHDC);
      end;
      LGraphics.DrawImage(LIcon, GetSystemMetrics(SM_CXEDGE), GetSystemMetrics(SM_CYEDGE));
      FSyncEditButtonNormalBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
      if (Assigned(FSyncEditButtonHotBitmap)) then FSyncEditButtonHotBitmap.Free();
      if (not StyleServices.Enabled) then
      begin
        LBrush.SetColor(ColorRefToARGB(ColorToRGB(clBtnFace)));
        LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
        LHDC := LGraphics.GetHDC();
        DrawEdge(LHDC, LRect, BDR_RAISED, BF_RECT);
        LGraphics.ReleaseHDC(LHDC);
      end
      else
      begin
        LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
        LHDC := LGraphics.GetHDC();
        StyleServices.DrawElement(LHDC, StyleServices.GetElementDetails(tbPushButtonHot), LRect);
        LGraphics.ReleaseHDC(LHDC);
      end;
      LGraphics.DrawImage(LIcon, GetSystemMetrics(SM_CXEDGE), GetSystemMetrics(SM_CYEDGE));
      FSyncEditButtonHotBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
      if (Assigned(FSyncEditButtonPressedBitmap)) then FSyncEditButtonPressedBitmap.Free();
      if (not StyleServices.Enabled) then
      begin
        LBrush.SetColor(ColorRefToARGB(ColorToRGB(clBtnFace)));
        LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
        LHDC := LGraphics.GetHDC();
        DrawEdge(LHDC, LRect, BDR_SUNKENOUTER, BF_RECT);
        LGraphics.ReleaseHDC(LHDC);
      end
      else
      begin
        LGraphics.FillRectangle(LBrush, 0, 0, LWidth, LHeight);
        LHDC := LGraphics.GetHDC();
        StyleServices.DrawElement(LHDC, StyleServices.GetElementDetails(tbPushButtonPressed), LRect);
        LGraphics.ReleaseHDC(LHDC);
      end;
      LGraphics.DrawImage(LIcon, GetSystemMetrics(SM_CXEDGE), GetSystemMetrics(SM_CYEDGE));
      FSyncEditButtonPressedBitmap := TGPCachedBitmap.Create(LBitmap, APaintVar^.Graphics);
      LGraphics.Free();
      LBitmap.Free();
      LIcon.Free();
    end;

    LBrush.Free();
    LPen.Free();
  end;

  procedure BuildOverlaysFromSyncEdit();
  var
    LCurrentId: Integer;
    LCurrentIndex: Integer;
    LIndex: Integer;
    LOverlay: TOverlay;
  begin
    InvalidateOverlays();

    if (FLines.SyncEdit) then
    begin
      LCurrentIndex := -1;
      LCurrentId := -1;
      for LIndex := 0 to FLines.SyncEditItems.Count - 1 do
        if (FLines.SyncEditItems[LIndex].Area.Contains(FLines.CaretPosition)
          or (FLines.SyncEditItems[LIndex].Area.EndPosition = FLines.CaretPosition)) then
        begin
          LCurrentIndex := LIndex;
          LCurrentId := FLines.SyncEditItems[LIndex].Id;
          break;
        end;

      for LIndex := 0 to FLines.SyncEditItems.Count - 1 do
        if (LIndex <> LCurrentIndex) then
        begin
          LOverlay.Area := FLines.SyncEditItems[LIndex].Area;
          if (FLines.SyncEditItems[LIndex].Id = LCurrentId) then
            LOverlay.Style := osRect
          else
            LOverlay.Style := osUnderline;
          FOverlays.Add(LOverlay);
        end;
    end;
  end;

var
  LIndex: Integer;
  LInsertPos: TPoint;
  LPaintVar: TPaintVar;
begin
  if (not ARect.IsEmpty()) then
  begin
    LPaintVar.Graphics := TGPGraphics.Create(APaintHelper.Handle);
    LPaintVar.LeftMarginBorderBrush := TGPSolidBrush.Create(ColorRefToARGB(ColorToRGB(Color)));
    LPaintVar.LineForegroundColor := clNone;
    LPaintVar.LineBackgroundColor := clNone;
    LPaintVar.OverlayIndex := 0;
    LPaintVar.Parts := TList<TPaintVar.TPart>.Create();
    LPaintVar.PreviousBackgroundColor := clNone;
    LPaintVar.PreviousFontStyles := [];
    LPaintVar.SearchResultIndex := 0;
    LPaintVar.SelArea := FLines.SelArea;
    if (FUCCVisible) then
      if (FColors.SpecialChars.Foreground <> clNone) then
        LPaintVar.UCCBrush := TGPSolidBrush.Create(ColorRefToARGB(ColorToRGB(FColors.SpecialChars.Foreground)))
      else
        LPaintVar.UCCBrush := TGPSolidBrush.Create(ColorRefToARGB(ColorToRGB(clGrayText)));

    Include(FState, esPainting);
    try
      if (FState * [esFontChanged, esSysFontChanged, esHighlighterChanged] <> []) then
      begin
        FFontPitchFixed := EnumFontFamilies(APaintHelper.Handle, PChar(Font.Name),
          @EnumFontsFamiliesProc, 0);

        APaintHelper.Font := Font;
        APaintHelper.Style := [];
        FLineHeight := APaintHelper.TextHeight(BCEDITOR_SPACE_CHAR, 1);

        FMaxDigitWidth := APaintHelper.TextWidth('0', 1);
        for LIndex := 1 to 9 do
          FMaxDigitWidth := Max(FMaxDigitWidth, APaintHelper.TextWidth(PChar(IntToStr(LIndex)), 1));
        LinesChanged();

        FSpaceWidth := APaintHelper.TextWidth(BCEDITOR_SPACE_CHAR, 1);
        FTabSignWidth := APaintHelper.TextWidth(#187, 1);
        FLineBreakSignWidth := APaintHelper.TextWidth(#182, 1);
        FMinusSignWidth := APaintHelper.TextWidth('-', 1);
        FCodeFoldingCollapsedMarkWidth := APaintHelper.TextWidth(BCEDITOR_CODEFOLDING_COLLAPSEDMARK, StrLen(BCEDITOR_CODEFOLDING_COLLAPSEDMARK));

        APaintHelper.Style := [fsBold];
        FBoldDotSignWidth := APaintHelper.TextWidth(#183, 1);

        FCodeFoldingWidth := Min(FLineHeight, GetSystemMetrics(SM_CXSMICON));
        UpdateMetrics();

        if (FFontPitchFixed) then
          FCaretWidth := GetSystemMetrics(SM_CXEDGE)
        else
          FCaretWidth := Max(1, GetSystemMetrics(SM_CXEDGE) div 2);
        InvalidateCaret();

        BuildBitmaps(@LPaintVar);
      end;

      if (esRowsInvalid in FState) then
      begin
        // FBuildRowsThread.WaitFor does not block the handling of Windows
        // Messages, like WM_SETFOCUS or WM_SIZE. WaitForSingleObject does it.
        if (Assigned(FBuildRowsThread)) then
        begin
          FBuildRowsCriticalSection.Enter();
          FBuildRowsThread.Terminate();
          FBuildRowsCriticalSection.Leave();

          WaitForSingleObject(FBuildRowsThread.Handle, INFINITE);
          FBuildRowsThread.Free();
          FBuildRowsThread := nil;
        end;
        Exclude(FState, esRowsInvalid);
        FRows.BeginBuild();

        FBuildRowsThread := TBuildRowsThread.Create(Self);
        if (csDesigning in ComponentState) then
          WaitForSingleObject(FBuildRowsThread.Handle, INFINITE);
      end;

      if (esSyncEditInvalid in FState) then
      begin
        FLines.CheckSyncEdit(FHighlighter, SyncEditChecked);
        Exclude(FState, esSyncEditInvalid);
      end;

      if (esMatchedPairInvalid in FState) then
      begin
        if ((eoHighlightMatchingPairs in FOptions) and (FHighlighter.MatchingPairs.Count > 0)) then
          FLines.StartScanMatchingPair(FHighlighter, MatchingPairScanned);
        Exclude(FState, esMatchedPairInvalid);
      end;

      if (esSyncEditOverlaysInvalid in FState) then
      begin
        BuildOverlaysFromSyncEdit();
        Exclude(FState, esSyncEditOverlaysInvalid);
      end;

      if (FOverlays.Count > 0) then
      begin
        LPaintVar.OverlayRectBrush := TGPSolidBrush.Create(ColorRefToARGB(ColorToRGB(Colors.SyncEdit.Overlay)));
        LPaintVar.OverlayUnderlineBrush := TGPSolidBrush.Create(ColorRefToARGB(ColorToRGB(Colors.SyncEdit.Overlay)));
      end;

      ProcessClient(cjPaint, APaintHelper, @LPaintVar, ARect, mbLeft, [], Point(-1, -1), AOverlays);

      if (not InvalidPoint(FInsertPos)) then
      begin
        LInsertPos := FInsertPos;
        FInsertPos := InvalidPos;
        SetInsertPos(LInsertPos);
      end;

      FState := FState - [esFontChanged, esHighlighterChanged, esSizeChanged, esSysFontChanged];
    finally
      LPaintVar.Graphics.Free();
      LPaintVar.LeftMarginBorderBrush.Free();
      if (FOverlays.Count > 0) then
      begin
        LPaintVar.OverlayRectBrush.Free();
        LPaintVar.OverlayUnderlineBrush.Free();
      end;
      LPaintVar.Parts.Free();
      if (FUCCVisible) then
        LPaintVar.UCCBrush.Free();

      Exclude(FState, esPainting);
    end;

    if (not (eoHighlightActiveLine in FOptions)) then
      FOldActiveLine := -1
    else
      FOldActiveLine := FLines.CaretPosition.Line;
    FOldSelArea := FLines.SelArea;
  end;
end;

procedure TCustomBCEditor.PasteFromClipboard();
var
  LClipboardData: Pointer;
  LGlobal: HGLOBAL;
  LOpened: Boolean;
  LRetry: Integer;
  LText: string;
begin
  LRetry := 0;
  repeat
    LOpened := OpenClipboard(WindowHandle);
    if (not LOpened) then
    begin
      Sleep(50);
      Inc(LRetry);
    end;
  until (LOpened or (LRetry = 10));

  if (not LOpened) then
    raise EClipboardException.CreateFmt(SCannotOpenClipboard, [SysErrorMessage(GetLastError)])
  else
  begin
    try
      LGlobal := GetClipboardData(CF_UNICODETEXT);
      if (LGlobal <> 0) then
      begin
        LClipboardData := GlobalLock(LGlobal);
        if (Assigned(LClipboardData)) then
          LText := StrPas(PChar(LClipboardData));
        GlobalUnlock(LGlobal);
      end;
    finally
      CloseClipboard();
    end;

    FLines.BeginUpdate();
    try
      FLines.UndoGroupBreak();
      DoInsertText(LText);
    finally
      FLines.EndUpdate();
    end;
  end;
end;

function TCustomBCEditor.PosToCharIndex(const APos: TPoint): Integer;
begin
  Result := FLines.CharIndexOf(APos);
end;

function TCustomBCEditor.PreviousWordPosition(const ALinesPosition: TBCEditorLinesPosition): TBCEditorLinesPosition;
begin
  if (ALinesPosition.Line < FLines.Count) then
    Result := Min(ALinesPosition, FLines.EOLPosition[ALinesPosition.Line])
  else
    Result := FLines.EOFPosition;

  if (Result.Char > 0) then
    while ((Result.Char > 0) and IsWordBreakChar(FLines.Items[Result.Line].Text[1 + Result.Char - 1])) do
      Dec(Result.Char)
  else if (Result.Line > 0) then
    Result := FLines.EOLPosition[Result.Line - 1]
  else
    Result := FLines.BOFPosition;
end;

function TCustomBCEditor.ProcessClient(const AJob: TClientJob;
  const APaintHelper: TPaintHelper; const APaintVar: PPaintVar; const AClipRect: TRect;
  const AButton: TMouseButton; const AShift: TShiftState; AMousePoint: TPoint;
  const APaintOverlays: Boolean = True): Boolean;

  function ProcessMarks(const APaintHelper: TPaintHelper; var ARect: TRect; const ALine, ARow: Integer): Boolean;
  var
    LBookmark: TBCEditorLines.TMark;
    LIndex: Integer;
    LLeft: Integer;
    LMark: TBCEditorLines.TMark;
    LRect: TRect;
  begin
    Result := False;

    LRect := ARect;
    LRect.Right := LRect.Left + FMetrics.MarksPanelRect.Width;

    case (AJob) of
      cjPaint:
        if (LRect.IntersectsWith(AClipRect)) then
        begin
          if (csOpaque in ControlStyle) then
          begin
            if (Colors.Marks.Background <> clNone) then
              APaintHelper.BackgroundColor := Colors.Marks.Background
            else
              APaintHelper.BackgroundColor := Color;
            APaintHelper.FillRect(LRect);
          end;

          if ((ARow < FRows.Count)
            and (rfFirstRowOfLine in FRows.Items[ARow].Flags)) then
          begin
            LLeft := LRect.Left;

            LBookmark := nil;
            for LIndex := FLines.Bookmarks.Count - 1 downto 0 do
              if (FLines.Bookmarks[LIndex].Pos.Y = ALine) then
                LBookmark := FLines.Bookmarks[LIndex];
            if (Assigned(LBookmark)) then
              APaintVar^.Graphics.DrawCachedBitmap(FBookmarkBitmaps[LBookmark.Index], LLeft, LRect.Top);

            LMark := nil;
            for LIndex := FLines.Marks.Count - 1 downto 0 do
              if (FLines.Marks[LIndex].Pos.Y = ALine) then
                LBookmark := FLines.Marks[LIndex];
            if (Assigned(LMark)) then
            begin
              if (Assigned(LBookmark)) then
                Inc(LLeft, GetSystemMetrics(SM_CXSMICON) div 4);

              if (Assigned(LMark)) then
                ImageList_DrawEx(FLeftMargin.Marks.Images.Handle, LMark.ImageIndex,
                  APaintHelper.Handle, LLeft, LRect.Top, 0, 0, CLR_DEFAULT, CLR_DEFAULT, ILD_TRANSPARENT);
            end;
          end;
        end;
      cjMouseDown:
        if ((MouseCapture in [mcNone, mcMarks])
          and LRect.Contains(AMousePoint) and not FSyncEditButtonRect.Contains(AMousePoint)
          and (AButton = mbLeft)) then
        begin
          MouseCapture := mcMarks;
          Result := True;
        end;
      cjMouseMove:
        if ((MouseCapture in [mcNone])
          and LRect.Contains(AMousePoint) and not FSyncEditButtonRect.Contains(AMousePoint)) then
        begin
          Cursor := crDefault;
          Result := True;
        end
        else if (MouseCapture = mcMarks) then
        begin
          if (not LRect.Contains(AMousePoint) or FSyncEditButtonRect.Contains(AMousePoint)) then
            MouseCapture := mcNone;
          Result := True;
        end;
      cjMouseUp:
        if ((MouseCapture in [mcNone, mcMarks])
          and LRect.Contains(AMousePoint) and not FSyncEditButtonRect.Contains(AMousePoint)
          and (AButton = mbLeft)) then
        begin
          if ((ALine <> -1) and Assigned(FOnMarksPanelClick)) then
            FOnMarksPanelClick(Self, ALine);
          MouseCapture := mcNone;
          Result := True;
        end;
    end;

    ARect.Left := LRect.Right;
  end;

  function ProcessLineNumber(const APaintHelper: TPaintHelper; var ARect: TRect; const ALine, ARow: Integer): Boolean;
  var
    LOptions: Longint;
    LRect: TRect;
    LText: string;
    LWidth: Integer;
  begin
    Result := False;

    LRect := ARect;
    LRect.Right := LRect.Left + FMetrics.LineNumbersRect.Width;

    case (AJob) of
      cjPaint:
        if (LRect.IntersectsWith(AClipRect)) then
        begin
          if (Colors.LineNumbers.Foreground <> clNone) then
            APaintHelper.ForegroundColor := Colors.LineNumbers.Foreground
          else
            APaintHelper.ForegroundColor := Font.Color;
          if (Colors.LineNumbers.Background <> clNone) then
            APaintHelper.BackgroundColor := Colors.LineNumbers.Background
          else
            APaintHelper.BackgroundColor := Color;

          if ((ARow = 0) and ((FRows.Count = 0) or (FLines.Count = 0))) then
          begin
            APaintHelper.Style := [];
            LText := IntToStr(FLeftMargin.LineNumbers.Offset);
            LWidth := APaintHelper.TextWidth(PChar(LText), Length(LText));
          end
          else if ((ALine < 0) and not (lnoAfterLastLine in FLeftMargin.LineNumbers.Options)
            or (0 <= ARow) and (ARow < FRows.Count) and not (rfFirstRowOfLine in FRows.Items[ARow].Flags)) then
          begin
            APaintHelper.Style := [];
            LText := '';
            LWidth := 0;
          end
          else if (((FRows.Count = 0) or (rfFirstRowOfLine in FRows.Items[ARow].Flags))
            and ((ALine = 0)
              or (ALine = FLines.CaretPosition.Line)
              or ((ALine + FLeftMargin.LineNumbers.Offset) mod 10 = 0)
              or not (lnoIntens in FLeftMargin.LineNumbers.Options))) then
          begin
            APaintHelper.Style := [];
            LText := IntToStr(ALine + FLeftMargin.LineNumbers.Offset);
            LWidth := APaintHelper.TextWidth(PChar(LText), Length(LText));
          end
          else if ((ALine + FLeftMargin.LineNumbers.Offset) mod 5 = 0) then
          begin
            APaintHelper.Style := [];
            LText := '-';
            LWidth := FMinusSignWidth;
          end
          else
          begin
            APaintHelper.Style := [fsBold];
            LText := #183;
            LWidth := FBoldDotSignWidth;
          end;

          if (csOpaque in ControlStyle) then
            LOptions := ETO_OPAQUE
          else
            LOptions := 0;

          APaintHelper.ExtTextOut(
            LRect.Right - LWidth - GPadding,
            LRect.Top,
            LOptions, LRect, PChar(LText), Length(LText), nil);
        end;
      cjMouseDown:
        if ((MouseCapture in [mcNone])
          and LRect.Contains(AMousePoint) and not FSyncEditButtonRect.Contains(AMousePoint)
          and (ALine >= 0)) then
          AMousePoint.X := FLeftMarginWidth;
      cjMouseMove:
        if ((MouseCapture in [mcNone])
          and (LRect.Contains(AMousePoint) and not FSyncEditButtonRect.Contains(AMousePoint))) then
        begin
          Cursor := crDefault;
          Result := True;
        end;
    end;

    ARect.Left := LRect.Right;
  end;

  function ProcessLineState(const APaintHelper: TPaintHelper; var ARect: TRect; const ALine, ARow: Integer): Boolean;
  var
    LRect: TRect;
  begin
    Result := False;

    LRect := ARect;
    LRect.Right := LRect.Left + FMetrics.LineStateRect.Width;

    case (AJob) of
      cjPaint:
        if (LRect.IntersectsWith(AClipRect)
          and (csOpaque in ControlStyle)) then
        begin
          if (not (csDesigning in ComponentState)
            and (ALine >= 0) and (ARow < FRows.Count)) then
          begin
            case (FLines.Items[ALine].State) of
              lsModified:
                if (FColors.LineState.Modified <> clNone) then
                  APaintHelper.BackgroundColor := FColors.LineState.Modified
                else
                  APaintHelper.BackgroundColor := Color;
              lsSaved:
                if (FColors.LineState.Saved <> clNone) then
                  APaintHelper.BackgroundColor := FColors.LineState.Saved
                else
                  APaintHelper.BackgroundColor := Color;
              else
                if (FColors.LineState.Loaded <> clNone) then
                  APaintHelper.BackgroundColor := FColors.LineState.Loaded
                else
                  APaintHelper.BackgroundColor := Color;
            end
          end
          else
            if (FColors.LineState.Loaded <> clNone) then
              APaintHelper.BackgroundColor := FColors.LineState.Loaded
            else
              APaintHelper.BackgroundColor := Color;
          APaintHelper.FillRect(LRect);
        end;
      cjMouseMove:
        if ((MouseCapture in [mcNone, mcLineState])
          and LRect.Contains(AMousePoint) and not FSyncEditButtonRect.Contains(AMousePoint)) then
        begin
          Cursor := crDefault;
          Result := True;
        end;
    end;

    ARect.Left := LRect.Right;
  end;

  function ProcessCodeFolding(const APaintHelper: TPaintHelper; var ARect: TRect; const ALine, ARow: Integer): Boolean;
  var
    LBitmap: TGPCachedBitmap;
    LRange: TBCEditorCodeFoldingRanges.TRange;
    LRect: TRect;
  begin
    Result := False;

    LRect := ARect;
    LRect.Right := LRect.Left + FMetrics.CodeFoldingRect.Width;

    if (ALine < 0) then
      LRange := nil
    else
      LRange := CodeFoldingCollapsableFoldRangeForLine(ALine);

    case (AJob) of
      cjPaint:
        if (LRect.IntersectsWith(AClipRect)) then
        begin
          if (Assigned(LRange) and LRange.Collapsable) then
            if (LRange.Collapsed) then
              LBitmap := FCodeFoldingCollapsedBitmap
            else
              LBitmap := FCodeFoldingExpandedBitmap
          else if ((0 <= ALine) and (ALine < FLines.Count) and FLines.Items[ALine].CodeFolding.TreeLine) then
            LBitmap := FCodeFoldingLineBitmap
          else if ((0 <= ALine) and (ALine < FLines.Count) and Assigned(FLines.Items[ALine].CodeFolding.EndRange)) then
            LBitmap := FCodeFoldingEndLineBitmap
          else
            LBitmap := FCodeFoldingNoneBitmap;
          APaintVar^.Graphics.DrawCachedBitmap(LBitmap, LRect.Left, LRect.Top)
        end;
      cjMouseDown:
        if ((MouseCapture in [mcNone, mcCodeFolding])
          and LRect.Contains(AMousePoint) and not FSyncEditButtonRect.Contains(AMousePoint)
          and (AButton = mbLeft)
          and Assigned(LRange) and LRange.Collapsable) then
        begin
          if (not LRange.Collapsed) then
            CollapseCodeFoldingRange(LRange)
          else
            ExpandCodeFoldingRange(LRange);
          Result := True;
        end;
      cjMouseMove:
        if ((MouseCapture in [mcNone, mcCodeFolding])
          and LRect.Contains(AMousePoint) and not FSyncEditButtonRect.Contains(AMousePoint)) then
        begin
          Cursor := crDefault;
          Result := True;
        end;
    end;

    ARect.Left := LRect.Right;
  end;

  function ProcessLeftMarginBorder(const APaintHelper: TPaintHelper; var ARect: TRect; const ALine, ARow: Integer): Boolean;
  var
    LRect: TRect;
  begin
    Result := False;

    LRect := ARect;
    LRect.Right := LRect.Left + FLeftMarginBorderWidth;

    case (AJob) of
      cjPaint:
        if (LRect.IntersectsWith(AClipRect)
          and (csOpaque in ControlStyle)) then
          APaintVar^.Graphics.FillRectangle(APaintVar^.LeftMarginBorderBrush, LRect.Left, LRect.Top, LRect.Width, LRect.Height);
      cjMouseDown,
      cjMouseDblClk,
      cjMouseTrplClk,
      cjMouseUp,
      cjHint:
        if (LRect.Contains(AMousePoint)) then
          AMousePoint.X := LRect.Right;
      cjMouseMove:
        if ((MouseCapture = mcNone)
          and LRect.Contains(AMousePoint)) then
          Cursor := crDefault;
    end;

    ARect.Left := LRect.Right;
  end;

  function ProcessSyncEditButton(const APaintHelper: TPaintHelper): Boolean;
  var
    LRow: Integer;
  begin
    Result := False;

    if (FLines.SyncEdit) then
    begin
      LRow := LinesToRows(FLines.SyncEditArea.BeginPosition).Row;
      LRow := Max(LRow, FTopRow);
      LRow := Min(LRow, FTopRow + FUsableRows);
    end
    else if (lsSyncEditAvailable in FLines.State) then
      LRow := LinesToRows(FLines.SelArea.EndPosition).Row
    else
      LRow := -1;

    if (LRow = -1) then
      FSyncEditButtonRect := InvalidRect
    else
    begin
      FSyncEditButtonRect.Left := 2 * GetSystemMetrics(SM_CXEDGE);
      FSyncEditButtonRect.Top := (LRow - FTopRow) * FLineHeight;
      FSyncEditButtonRect.Right := FSyncEditButtonRect.Left + GetSystemMetrics(SM_CXSMICON) + 2 * GetSystemMetrics(SM_CXEDGE);
      FSyncEditButtonRect.Bottom := FSyncEditButtonRect.Top + GetSystemMetrics(SM_CYSMICON) + 2 * GetSystemMetrics(SM_CYEDGE);

      case (AJob) of
        cjPaint,
        cjPaintOverlays:
          if (APaintOverlays
            and FSyncEditButtonRect.IntersectsWith(AClipRect)) then
            if (not FLines.SyncEdit) then
              APaintVar^.Graphics.DrawCachedBitmap(FSyncEditButtonNormalBitmap, FSyncEditButtonRect.Left, FSyncEditButtonRect.Top)
            else
              APaintVar^.Graphics.DrawCachedBitmap(FSyncEditButtonPressedBitmap, FSyncEditButtonRect.Left, FSyncEditButtonRect.Top);
        cjMouseDown:
          if ((MouseCapture in [mcNone, mcSyncEditButton])
            and FSyncEditButtonRect.Contains(AMousePoint)
            and (AButton = mbLeft)) then
          begin
            InvalidateRect(FSyncEditButtonRect, True);
            MouseCapture := mcSyncEditButton;
            Result := True;
          end;
        cjMouseMove:
          if ((MouseCapture in [mcNone, mcSyncEditButton])
            and FSyncEditButtonRect.Contains(AMousePoint)) then
          begin
            if (MouseCapture <> mcSyncEditButton) then
            begin
              InvalidateRect(FSyncEditButtonRect, True);
              MouseCapture := mcSyncEditButton;
            end;
          end
          else if (MouseCapture = mcSyncEditButton) then
          begin
            InvalidateRect(FSyncEditButtonRect, True);
            if (not FSyncEditButtonRect.Contains(AMousePoint)) then
              MouseCapture := mcNone;
          end;
        cjMouseUp:
          if ((MouseCapture in [mcNone, mcSyncEditButton])
            and FSyncEditButtonRect.Contains(AMousePoint)
            and (AButton = mbLeft)) then
          begin
            ProcessCommand(ecSyncEdit);
            MouseCapture := mcNone;
            Result := True;
          end;
      end;
    end;
  end;

  procedure ProcessScroll(const APaintHelper: TPaintHelper);
  var
    LLinesPosition: TBCEditorLinesPosition;
  begin
    LLinesPosition := ClientToLines(AMousePoint.X, AMousePoint.Y);
    if (LLinesPosition <> FLines.CaretPosition) then
      SetCaretPosition(LLinesPosition, True);
  end;

  function ProcessScrolling(): Boolean;
  var
    LTextPos: TPoint;
  begin
    Result := False;

    case (AJob) of
      cjPaint,
      cjPaintOverlays:
        if (APaintOverlays
          and (esScrolling in FState)
          and FScrollingRect.IntersectsWith(AClipRect)) then
          APaintVar^.Graphics.DrawCachedBitmap(FScrollingBitmap, FScrollingRect.Left, FScrollingRect.Top);
      cjMouseDown:
        if (esScrolling in FState) then
        begin
          Exclude(FState, esScrolling);
          MouseCapture := mcNone;
          InvalidateRect(FScrollingRect, True);
          ScrollTo(FTextPos); // Pleace TopRow to the top
          Result := True;
        end
        else if (Rect(FLeftMarginWidth, 0, FMetrics.ClientRect.Width, FMetrics.ClientRect.Height).Contains(AMousePoint)
          and (AButton = mbMiddle)) then
        begin
          FScrollingPoint := AMousePoint;
          FScrollingRect.Left := FScrollingPoint.X - FScrollingBitmapWidth div 2;
          FScrollingRect.Top := FScrollingPoint.Y - FScrollingBitmapHeight div 2;
          FScrollingRect.Right := FScrollingPoint.X + FScrollingBitmapWidth div 2;
          FScrollingRect.Bottom := FScrollingPoint.Y + FScrollingBitmapHeight div 2;
          InvalidateRect(FScrollingRect, True);
          Include(FState, esScrolling);
          Cursor := crSizeAll;
          MouseCapture := mcScrolling;
          SetTimer(WindowHandle, tiScrolling, GClientRefreshTime, nil);
          Result := True;
        end;
      cjScrolling:
        if (MouseCapture = mcScrolling) then
        begin
          LTextPos := FTextPos;
          if (AMousePoint.X < FScrollingPoint.X) then
            Inc(LTextPos.X, Min(0, (AMousePoint.X - FScrollingPoint.X) div 2 + GetSystemMetrics(SM_CXEDGE)))
          else
            Inc(LTextPos.X, Max(0, (AMousePoint.X - FScrollingPoint.X) div 2 - GetSystemMetrics(SM_CXEDGE)));
          if (AMousePoint.Y < FScrollingPoint.Y) then
            Inc(LTextPos.Y, Min(0, (AMousePoint.Y - FScrollingPoint.Y) div 2 + GetSystemMetrics(SM_CXEDGE)))
          else
            Inc(LTextPos.Y, Max(0, (AMousePoint.Y - FScrollingPoint.Y) div 2 - GetSystemMetrics(SM_CXEDGE)));
          ScrollTo(LTextPos, False);
        end;
    end;
  end;

var
  LBeginRange: TBCEditorHighlighter.TRange;
  LChar: Integer;
  LCodeFoldingRange: TBCEditorCodeFoldingRanges.TRange;
  LColumn: Integer;
  LLeft: Integer;
  LLength: Integer;
  LLine: Integer;
  LMouseRect: TRect;
  LPaintHelper: TPaintHelper;
  LRowRect: TRect;
  LRow: Integer;
  LText: PChar;
  LTextClipRect: TRect;
  LToken: TBCEditorHighlighter.TTokenFind;
begin
  Result := False;

  if (FLineHeight > 0) then
  begin
    if (not Assigned(APaintHelper)) then
    begin
      FPaintHelper.BeginDraw(Canvas.Handle);
      LPaintHelper := FPaintHelper;
    end
    else
      LPaintHelper := APaintHelper;
    try
      LTextClipRect := AClipRect;
      LTextClipRect.Intersect(FMetrics.TextRect);

      if ((AJob in [cjPaint, cjPaintOverlays])
        or not (seoShowButton in FSyncEditOptions)) then
        FSyncEditButtonRect := InvalidRect
      else
        Result := Result or ProcessSyncEditButton(LPaintHelper);

      if (not (AJob in [cjPaint, cjPaintOverlays])
        and FScrollingEnabled) then
        Result := Result or ProcessScrolling();

      LRowRect.Left := 0;
      LRowRect.Top := - FTextPos.Y mod FLineHeight - FLineHeight;
      LRowRect.Right := FMetrics.ClientRect.Width;
      LRowRect.Bottom := LRowRect.Top + FLineHeight;

      if (not (AJob in [cjPaintOverlays])) then
        for LRow := FTopRow to FTopRow + FVisibleRows do
          if (not Result) then
          begin
            Inc(LRowRect.Top, FLineHeight);
            Inc(LRowRect.Bottom, FLineHeight);

            LMouseRect := LRowRect;
            if (MouseCapture <> mcNone) then
            begin
              LMouseRect.Left := Min(LMouseRect.Left, AMousePoint.X);
              LMouseRect.Right := Max(LMouseRect.Right, AMousePoint.X);
              if (LRow = FTopRow) then
                LMouseRect.Top := Min(LMouseRect.Top, AMousePoint.Y);
              if (LRow = FTopRow + FVisibleRows) then
                LMouseRect.Bottom := Max(LMouseRect.Bottom, AMousePoint.Y);
            end;

            if ((AJob = cjPaint) and LRowRect.IntersectsWith(AClipRect)
              or (AJob <> cjPaint) and LMouseRect.Contains(AMousePoint)) then
            begin
              if (LRow < FRows.Count) then
                LLine := FRows.Items[LRow].Line
              else
              begin
                LLine := -1;
                if ((AJob = cjPaint) and (FRowsWanted.What = rwNothing)) then
                begin
                  FBuildRowsCriticalSection.Enter();
                  try
                    if (rsBuilding in FRows.State) then
                    begin
                      FRowsWanted.What := rwPaintText;
                      FRowsWanted.Row := LRow;
                      UpdateCursor();
                    end;
                  finally
                    FBuildRowsCriticalSection.Leave();
                  end;
                end;
              end;

              if (FLeftMargin.Bookmarks.Visible or FLeftMargin.Marks.Visible) then
                Result := Result or ProcessMarks(LPaintHelper, LRowRect, LLine, LRow);

              if (FLeftMargin.LineNumbers.Visible) then
                Result := Result or ProcessLineNumber(LPaintHelper, LRowRect, LLine, LRow);

              if (FLeftMargin.LineState.Visible) then
                Result := Result or ProcessLineState(LPaintHelper, LRowRect, LLine, LRow);

              if (FLeftMargin.CodeFolding.Visible) then
                Result := Result or ProcessCodeFolding(LPaintHelper, LRowRect, LLine, LRow);

              if (FLeftMarginWidth > 0) then
                Result := Result or ProcessLeftMarginBorder(LPaintHelper, LRowRect, LLine, LRow);

              if (not Result) then
              begin
                if (AJob = cjMouseTrplClk) then
                begin
                  if ((AButton = mbLeft)
                    and (soTripleClickLineSelect in FSelectionOptions)
                    and (LRow < FRows.Count)) then
                  begin
                    ProcessCommand(ecSel, TBCEditorCommandDataSelection.Create(LinesArea(FRows.BORPosition[LRow], FRows.EORPosition[LRow])));
                    FLastDoubleClickTime := 0;
                    Result := True;
                  end;
                end
                else
                begin
                  if ((LRow < FRows.Count)
                    and (AJob <> cjScrolling)) then
                  begin
                    LLeft := FTextPos.X;
                    if (GetFindTokenData(LRow, LLeft, LBeginRange, LText, LLength, LChar, LColumn)
                      and FHighlighter.FindFirstToken(LBeginRange, LText, LLength, LChar, LToken)) then
                    begin
                      Dec(LRowRect.Left, FTextPos.X - LLeft);

                      if (Assigned(APaintVar)) then
                      begin
                        if ((0 <= LLine) and (LLine < FLines.Count) and (FLines.Items[LLine].Foreground <> clNone)) then
                          APaintVar^.LineForegroundColor := FLines.Items[LLine].Foreground
                        else
                          APaintVar^.LineForegroundColor := clNone;
                        if ((0 <= LLine) and (LLine < FLines.Count) and (FLines.Items[LLine].Background <> clNone)) then
                          APaintVar^.LineBackgroundColor := FLines.Items[LLine].Background
                        else
                          APaintVar^.LineBackgroundColor := clNone;
                        APaintVar^.PreviousFontStyles := [];
                        APaintVar^.PreviousBackgroundColor := clNone;
                        APaintVar^.PreviousUCC := False;
                      end;

                      repeat
                        Result := Result or ProcessToken(AJob, LPaintHelper, APaintVar, LTextClipRect, AButton, AShift, AMousePoint, LRowRect,
                          LinesPosition(FRows.Items[LRow].Char + LToken.Char, LLine),
                          RowsPosition(LColumn, LRow),
                          LToken.Text, LToken.Length,
                          @LToken);

                        if (LToken.Text^ = BCEDITOR_TAB_CHAR) then
                          Inc(LColumn, FTabs.Width - LColumn div FTabs.Width)
                        else
                          Inc(LColumn, LToken.Length);
                      until ((LRowRect.Left > FMetrics.ClientRect.Width)
                        or not FHighlighter.FindNextToken(LToken));
                      FHighlighter.FindClose(LToken);
                    end
                    else
                      Dec(LRowRect.Left, FTextPos.X);

                    if (LRowRect.Left <= FMetrics.ClientRect.Width) then
                    begin
                      if (not FLeftMargin.CodeFolding.Visible
                        or not (rfFirstRowOfLine in FRows.Items[LRow].Flags)) then
                        LCodeFoldingRange := nil
                      else
                      begin
                        LCodeFoldingRange := CodeFoldingCollapsableFoldRangeForLine(LLine);
                        if (Assigned(LCodeFoldingRange) and (not LCodeFoldingRange.Collapsed or LCodeFoldingRange.ParentCollapsed)) then
                          LCodeFoldingRange := nil;
                      end;
                      Result := Result or ProcessToken(AJob, LPaintHelper, APaintVar, LTextClipRect, AButton, AShift, AMousePoint, LRowRect,
                        FRows.EORPosition[LRow], RowsPosition(FRows.Items[LRow].Length, LRow),
                        nil, 0, nil, LCodeFoldingRange);
                    end;
                  end
                  else
                    Result := ProcessToken(AJob, LPaintHelper, APaintVar, LTextClipRect, AButton, AShift, AMousePoint, LRowRect,
                      FRows.BORPosition[LRow], RowsPosition(0, LRow),
                      nil, 0);
                end;
              end;

              LRowRect.Left := 0;
              LRowRect.Right := FMetrics.ClientRect.Width;
            end;
          end;

      if ((AJob = cjMouseMove)
        and not Result
        and (MouseCapture = mcText)) then
      begin
        ProcessScroll(LPaintHelper);
        SetTimer(WindowHandle, tiScroll, 100, nil);
      end;

      if ((AJob in [cjPaint, cjPaintOverlays])
        and (seoShowButton in FSyncEditOptions)) then
        Result := Result or ProcessSyncEditButton(LPaintHelper);

      if ((AJob in [cjPaint, cjPaintOverlays])
        and FScrollingEnabled) then
        Result := ProcessScrolling() or Result;
    finally
      if (not Assigned(APaintHelper)) then
        FPaintHelper.EndDraw();
    end;
  end;
end;

function TCustomBCEditor.ProcessCommand(const ACommand: TBCEditorCommand; const AData: TBCEditorCommandData = nil): Boolean;
var
  LAllow: Boolean;
  LCollapsedCount: Integer;
  LHandled: Boolean;
  LLine: Integer;
  LNewSelArea: TBCEditorLinesArea;
begin
  Assert((ACommand <= ecLast) or (ACommand >= ecUser));

  Assert(not (ecProcessingCommand in FState));
  Include(FState, ecProcessingCommand);

  if (ACommand = ecNone) then
    Result := False
  else
  begin
    LAllow := True;

    if ((ACommand = ecRecordMacro) and FLines.SyncEdit) then
      LAllow := ProcessCommand(ecSyncEdit);

    if (Assigned(FBeforeProcessCommand)) then
      FBeforeProcessCommand(Self, ACommand, AData, LAllow);

    LHandled := False;
    if (LAllow) then
    begin
      FHookedCommandHandlers.Broadcast(True, ACommand, AData, LHandled);

      if (not LHandled and (ACommand <> ecNone)) then
      begin
        FBuildRowsCriticalSection.Enter();
        try
          if (FRowsWanted.What <> rwNothing) then
          begin
            FRowsWanted.What := rwNothing;
            UpdateCursor();
          end;
        finally
          FBuildRowsCriticalSection.Leave();
        end;

        if (FLeftMargin.CodeFolding.Visible) then
          case (ACommand) of
            ecBackspace, ecDeleteChar, ecDeleteWord, ecDeleteLastWord, ecDeleteLine,
            ecClear, ecReturn, ecChar, ecText, ecCutToClipboard, ecPasteFromClipboard,
            ecBlockIndent, ecBlockUnindent, ecTab:
              if (not FLines.SelArea.IsEmpty()) then
              begin
                LNewSelArea := FLines.SelArea;
                LCollapsedCount := 0;
                for LLine := LNewSelArea.BeginPosition.Line to LNewSelArea.EndPosition.Line do
                  LCollapsedCount := ExpandCodeFoldingLines(LLine + 1);
                if LCollapsedCount <> 0 then
                begin
                  Inc(LNewSelArea.EndPosition.Line, LCollapsedCount);
                  LNewSelArea.EndPosition.Char := Length(FLines.Items[LNewSelArea.EndPosition.Line].Text);
                end;
                FLines.BeginUpdate();
                try
                  FLines.SelArea := LNewSelArea;
                finally
                  FLines.EndUpdate();
                end;
              end
              else
                ExpandCodeFoldingLines(FLines.CaretPosition.Line + 1);
          end;

        LHandled := True;
        case (ACommand) of
          ecAcceptDrop:
            ; // Do nothing, but LHandled should be True
          ecBackspace:
            DoBackspace();
          ecBlockComment:
            DoBlockComment();
          ecBlockIndent:
            DoBlockIndent(ACommand);
          ecBlockUnindent:
            DoBlockIndent(ACommand);
          ecBOF:
            DoBOF(ACommand);
          ecBOL:
            DoBOL(ACommand = ecSelBOL);
          ecCancel:
            if (FLines.SyncEdit) then
              DoSyncEdit()
            else if (esScrolling in FState) then
              ProcessClient(cjMouseDown, nil, nil, FMetrics.ClientRect, mbMiddle, [], FScrollingPoint)
            else if (not ReadOnly and not FLines.CanModify) then
              FLines.TerminateJob()
            else if (esHighlightSearchAllAreas in FState) then
            begin
              Exclude(FState, esHighlightSearchAllAreas);
              InvalidateText();
            end;
          ecClear:
            FLines.Clear();
          ecChar:
            DoChar(PBCEditorCommandDataChar(AData));
          ecCopyToClipboard:
            DoCopyToClipboard();
          ecCutToClipboard:
            DoCutToClipboard();
          ecDeleteChar:
            DeleteChar();
          ecDeleteLastWord:
            DeleteLastWordOrBOL(ACommand);
          ecDeleteLine:
            DeleteLine();
          ecDeleteToBOL:
            DeleteLastWordOrBOL(ACommand);
          ecDeleteToEOL:
            DoDeleteToEOL();
          ecDeleteWord:
            DoDeleteWord();
          ecDown:
            DoUpOrDown(1, ACommand = ecSelDown);
          ecDropOLE:
            DoDropOLE(PBCEditorCommandDataDropOLE(AData));
          ecEOF:
            DoEOF(ACommand);
          ecEOL:
            DoEOL(ACommand = ecSelEOL);
          ecFindFirst:
            DoFindFirst(PBCEditorCommandDataFind(AData));
          ecFindNext:
            if (FLastSearch = lsReplace) then
              DoReplace(FLastSearchData)
            else if (not Assigned(FLastSearchData)) then
              DoShowFind(True)
            else if (foBackwards in PBCEditorCommandDataFind(FLastSearchData)^.Options) then
              DoFindBackwards(PBCEditorCommandDataFind(FLastSearchData))
            else
              DoFindForewards(PBCEditorCommandDataFind(FLastSearchData));
          ecFindPrevious:
            if (FLastSearch = lsReplace) then
              DoReplace(FLastSearchData)
            else if (not Assigned(FLastSearchData)) then
              DoShowFind(True)
            else if (foBackwards in PBCEditorCommandDataFind(FLastSearchData)^.Options) then
              DoFindForewards(PBCEditorCommandDataFind(FLastSearchData))
            else
              DoFindBackwards(PBCEditorCommandDataFind(FLastSearchData));
          ecGotoBookmark1 ..
            ecGotoBookmark0: GotoBookmark(Ord(ACommand) - Ord(ecGotoBookmark1));
          ecGotoNextBookmark:
            GotoNextBookmark();
          ecGotoPreviousBookmark:
            GotoPreviousBookmark();
          ecInsertLine:
            InsertLine();
          ecInsertTextMode:
            TextEntryMode := temInsert;
          ecLeft:
            MoveCaretHorizontally(-1, ACommand = ecSelLeft);
          ecLineComment:
            DoLineComment();
          ecLowerCase:
            DoToggleSelectedCase(ACommand);
          ecOverwriteTextMode:
            TextEntryMode := temOverwrite;
          ecPageBottom:
            DoPageTopOrBottom(ACommand);
          ecPageDown:
            DoPageUpOrDown(ACommand);
          ecPageTop:
            DoPageTopOrBottom(ACommand);
          ecPageUp:
            DoPageUpOrDown(ACommand);
          ecPasteFromClipboard:
            PasteFromClipboard();
          ecPosition:
            DoPosition(PBCEditorCommandDataPosition(AData));
          ecRedo:
            FLines.Redo();
          ecReplace:
            DoReplace(AData);
          ecReturn:
            if (FWantReturns) then DoReturnKey();
          ecRight:
            MoveCaretHorizontally(1, ACommand = ecSelRight);
          ecScrollDown:
            DoScroll(ACommand);
          ecScrollLeft:
            DoScroll(ACommand);
          ecScrollRight:
            DoScroll(ACommand);
          ecScrollTo:
            DoScrollTo(AData);
          ecScrollUp:
            DoScroll(ACommand);
          ecSel:
            DoSelection(PBCEditorCommandDataSelection(AData));
          ecSelBOF:
            DoBOF(ACommand);
          ecSelBOL:
            DoBOL(ACommand = ecSelBOL);
          ecSelBOP:
            DoPageTopOrBottom(ACommand);
          ecSelDown:
            DoUpOrDown(1, ACommand = ecSelDown);
          ecSelectAll:
            DoSelectAll();
          ecSelEOF:
            DoEOF(ACommand);
          ecSelEOL:
            DoEOL(ACommand = ecSelEOL);
          ecSelEOP:
            DoPageTopOrBottom(ACommand);
          ecSelLeft:
            MoveCaretHorizontally(-1, ACommand = ecSelLeft);
          ecSelPageDown:
            DoPageUpOrDown(ACommand);
          ecSelPageUp:
            DoPageUpOrDown(ACommand);
          ecSelRight:
            MoveCaretHorizontally(1, ACommand = ecSelRight);
          ecSelUp:
            DoUpOrDown(-1, ACommand = ecSelUp);
          ecSelWord:
            SetSelectedWord;
          ecSelWordLeft:
            DoWordLeft(ACommand);
          ecSelWordRight:
            DoWordRight(ACommand);
          ecSetBookmark1 ..
            ecSetBookmark0: DoSetBookmark(ACommand);
          ecShiftTab:
            if (FWantTabs) then DoTabKey(ACommand);
          ecShowCompletionProposal:
            DoCompletionProposal();
          ecShowFind:
            DoShowFind(True);
          ecShowGotoLine:
            DoShowGotoLine();
          ecShowReplace:
            DoShowReplace();
          ecSyncEdit:
            DoSyncEdit();
          ecTab:
            if (FWantTabs) then DoTabKey(ACommand);
          ecText:
            DoText(PBCEditorCommandDataText(AData));
          ecToggleTextMode:
            if (FTextEntryMode = temInsert) then
              TextEntryMode := temOverwrite
            else
              TextEntryMode := temInsert;
          ecUndo:
            FLines.Undo();
          ecUnselect:
            DoUnselect();
          ecUp:
            DoUpOrDown(-1, ACommand = ecSelUp);
          ecUpperCase:
            DoToggleSelectedCase(ACommand);
          ecWordLeft:
            DoWordLeft(ACommand);
          ecWordRight:
            DoWordRight(ACommand);
          else
            LHandled := False;
        end;
      end;

      FHookedCommandHandlers.Broadcast(False, ACommand, AData, LHandled);
    end;

    if (Assigned(FAfterProcessCommand)) then
      FAfterProcessCommand(Self, ACommand, AData);

    Result := LHandled;
  end;

  Exclude(FState, ecProcessingCommand);
end;

function TCustomBCEditor.ProcessToken(const AJob: TClientJob;
  const APaintHelper: TPaintHelper;
  const APaintVar: PPaintVar; const AClipRect: TRect;
  const AButton: TMouseButton; const AShift: TShiftState; const AMousePoint: TPoint;
  var ARect: TRect;
  const ALinesPosition: TBCEditorLinesPosition;
  const ARowsPosition: TBCEditorRowsPosition;
  const AText: PChar; const ALength: Integer;
  const AToken: TBCEditorHighlighter.PTokenFind = nil;
  const ARange: TBCEditorCodeFoldingRanges.TRange = nil): Boolean;
var
  LEndPosition: TBCEditorLinesPosition;

  procedure AddPart(const APartBeginPosition, APartEndPosition: TBCEditorLinesPosition;
    const APartType: TPaintVar.TPart.TPartType);
  var
    LIndex: Integer;
    LPart: TPaintVar.TPart;
  begin
    LIndex := APaintVar^.Parts.Count - 1;
    while (LIndex >= 0) do
    begin
      if (APaintVar^.Parts.List[LIndex].BeginPosition = APartBeginPosition) then
      begin
        if (APaintVar^.Parts.List[LIndex].BeginPosition = APartBeginPosition) then
        begin
          if (APaintVar^.Parts.List[LIndex].EndPosition = APartEndPosition) then
            APaintVar^.Parts.List[LIndex].PartType := APartType
          else if (APaintVar^.Parts.List[LIndex].EndPosition > APartEndPosition) then
          begin
            APaintVar^.Parts.List[LIndex].BeginPosition := APartEndPosition;

            LPart.BeginPosition := APartBeginPosition;
            LPart.EndPosition := APartEndPosition;
            LPart.PartType := APartType;
            APaintVar^.Parts.Insert(LIndex, LPart);
          end
          else
          begin
            APaintVar^.Parts.List[LIndex].EndPosition := APartEndPosition;
            APaintVar^.Parts.List[LIndex].PartType := APartType;
            while ((LIndex < APaintVar^.Parts.Count) and (APaintVar^.Parts.List[LIndex].EndPosition < APartEndPosition)) do
              APaintVar^.Parts.Delete(LIndex);
            if (LIndex < APaintVar^.Parts.Count) then
              APaintVar^.Parts.List[LIndex].BeginPosition := APartEndPosition;
          end;
          exit;
        end
      end
      else if (APaintVar^.Parts.List[LIndex].BeginPosition < APartBeginPosition) then
      begin
        while ((LIndex >= 0) and (APaintVar^.Parts.List[LIndex].BeginPosition > APartBeginPosition)) do
        begin
          APaintVar^.Parts.Delete(LIndex);
          Dec(LIndex);
        end;
        if ((LIndex > 0) and (APaintVar^.Parts.List[LIndex - 1].EndPosition > APartBeginPosition)) then
          APaintVar^.Parts.List[LIndex - 1].EndPosition := APartBeginPosition;
        Inc(LIndex);
        break;
      end;

      Dec(LIndex);
    end;

    if (LIndex < 0) then
      LIndex := 0;

    LPart.BeginPosition := APartBeginPosition;
    LPart.EndPosition := APartEndPosition;
    LPart.PartType := APartType;
    if ((APaintVar^.Parts.Count > 0) and (LIndex < APaintVar^.Parts.Count)) then
      APaintVar^.Parts.Insert(LIndex, LPart)
    else
      APaintVar^.Parts.Add(LPart);
  end;

  procedure ApplyPart(const AArea: TBCEditorLinesArea; APartType: TPaintVar.TPart.TPartType);
  begin
    if (AArea <> InvalidLinesArea) then
      if ((AArea.BeginPosition <= ALinesPosition) and (ALinesPosition < AArea.EndPosition)) then
        AddPart(ALinesPosition, Min(LEndPosition, AArea.EndPosition), APartType)
      else if ((ALinesPosition < AArea.BeginPosition) and (AArea.BeginPosition < LEndPosition)) then
        AddPart(AArea.BeginPosition, Min(LEndPosition, AArea.EndPosition), APartType);
  end;

  procedure CompleteParts();
  var
    LIndex: Integer;
    LPosition: TBCEditorLinesPosition;
  begin
    LPosition := ALinesPosition;
    LIndex := 0;

    while (LPosition < LEndPosition) do
      if (LIndex = APaintVar^.Parts.Count) then
      begin
        AddPart(LPosition, LEndPosition, ptNormal);
        exit;
      end
      else if (LPosition < APaintVar^.Parts.List[LIndex].BeginPosition) then
      begin
        AddPart(LPosition, APaintVar^.Parts.List[LIndex].BeginPosition, ptNormal);
        Inc(LIndex);
        LPosition := LinesPosition(APaintVar^.Parts.List[LIndex].EndPosition.Char, APaintVar^.Parts.List[LIndex].EndPosition.Line);
      end
      else
      begin
        LPosition := LinesPosition(APaintVar^.Parts.List[LIndex].EndPosition.Char, APaintVar^.Parts.List[LIndex].EndPosition.Line);
        Inc(LIndex);
      end;
  end;

var
  LAddOnColor: TColor;
  LArea: TBCEditorLinesArea;
  LBackgroundColor: TColor;
  LBorderColor: TColor;
  LChar: Integer;
  LCollapsedMarkRect: TRect;
  LCursorPosition: TBCEditorLinesPosition;
  LEffect: Longint;
  LFontStyles: TFontStyles;
  LForegroundColor: TColor;
  LHint: string;
  LIsLineBreakToken: Boolean;
  LIsTabToken: Boolean;
  LIsUCCToken: Boolean;
  LLeft: Integer;
  LLength: Integer;
  LLine: Integer;
  LOptions: Longint;
  LOverlayBeginChar: Integer;
  LOverlayEndChar: Integer;
  LPartBackgroundColor: TColor;
  LPartForegroundColor: TColor;
  LPartIndex: Integer;
  LPartLength: Integer;
  LPartText: PChar;
  LRect: TRect;
  LRight: Integer;
  LSelArea: TBCEditorLinesArea;
  LSelLength: Integer;
  LSelStartAfter: Integer;
  LSelStartBefore: Integer;
  LStep: Integer;
  LText: PChar;
  LSize: TSize;
begin
  Result := False;

  LIsLineBreakToken := not Assigned(AText) and (ALinesPosition.Line < FLines.Count - 1);
  LIsTabToken := Assigned(AText) and (AText^ = BCEDITOR_TAB_CHAR);
  LIsUCCToken := Assigned(AText) and (ALength = 1) and AText^.IsInArray(BCEditor_UCCs);

  if (not LIsLineBreakToken) then
  begin
    LText := AText;
    LLength := ALength;
  end
  else if ((eoShowSpecialChars in FOptions)
    and (0 <= ARowsPosition.Row) and (ARowsPosition.Row < FRows.Count)
    and (rfLastRowOfLine in FRows.Items[ARowsPosition.Row].Flags)
    and (ALinesPosition.Line < FLines.Count - 1)) then
  begin
    LText := #182;
    LLength := 1;
  end
  else
  begin
    LText := #0;
    LLength := 0;
  end;

  if (Assigned(AToken) and Assigned(AToken^.Attribute)) then
    LFontStyles := AToken^.Attribute.FontStyles
  else
    LFontStyles := [];
  if (Assigned(LText)) then
    case (LText^) of
      BCEDITOR_NONE_CHAR:
        begin
          if (ALength > Length(FSpecialCharsNullText)) then
            if (eoShowSpecialChars in FOptions) then
              FSpecialCharsNullText := StringOfChar(Char(#127), ALength)
            else
              FSpecialCharsNullText := StringOfChar(#32, ALength);
          LText := PChar(FSpecialCharsNullText);
          if (eoShowSpecialChars in FOptions) then
            LFontStyles := LFontStyles - [fsBold];
        end;
      BCEDITOR_TAB_CHAR:
        begin
          if (eoShowSpecialChars in FOptions) then
            LText := #187
          else
            LText := #32;
          if (eoShowSpecialChars in FOptions) then
            LFontStyles := LFontStyles - [fsBold];
        end;
      BCEDITOR_LINEFEED,
      BCEDITOR_CARRIAGE_RETURN,
      BCEDITOR_SPACE_CHAR:
        begin
          if (ALength > Length(FSpecialCharsSpaceText)) then
            if (eoShowSpecialChars in FOptions) then
              FSpecialCharsSpaceText := StringOfChar(Char(#183), ALength)
            else
              FSpecialCharsSpaceText := StringOfChar(#32, ALength);
          LText := PChar(FSpecialCharsSpaceText);
          if (eoShowSpecialChars in FOptions) then
            LFontStyles := LFontStyles + [fsBold];
        end;
    end;
  APaintHelper.Style := LFontStyles;

  LRect := ARect;
  if (not Assigned(AText)) then
    LRect.Right := ARect.Right
  else if (LIsTabToken) then
    LRect.Right := LRect.Left + (FTabs.Width - ARowsPosition.Column mod FTabs.Width) * FTabSignWidth
  else if (LLength = 0) then
    LRect.Right := LRect.Left
  else if (FFontPitchFixed
    and not (lfContainsWideChar in FLines.Items[ALinesPosition.Line].Flags)) then
    LRect.Right := LRect.Left + LLength * FSpaceWidth
  else
    LRect.Right := LRect.Left + APaintHelper.TextWidth(LText, LLength);

  if (not Assigned(ARange)) then
    LCollapsedMarkRect := Rect(-1, -1, -1, -1)
  else
  begin
    LCollapsedMarkRect := Rect(
      LRect.Left + FSpaceWidth,
      LRect.Top + GLineWidth,
      LRect.Left + FSpaceWidth + 2 * GLineWidth + FCodeFoldingCollapsedMarkWidth + 2 * GLineWidth,
      LRect.Bottom - GLineWidth);
    if (eoShowSpecialChars in FOptions) then
    begin
      Inc(LCollapsedMarkRect.Left, FLineBreakSignWidth);
      Inc(LCollapsedMarkRect.Right, FLineBreakSignWidth);
    end;
  end;

  case (AJob) of
    cjPaint:
      if (LRect.IntersectsWith(AClipRect)
        and (not LIsLineBreakToken or (ALinesPosition.Line < FLines.Count - 1))) then
      begin
        LEndPosition := LinesPosition(ALinesPosition.Char + LLength, ALinesPosition.Line);


        if (not Assigned(APaintVar)) then
          LForegroundColor := clNone
        else if (APaintVar^.LineForegroundColor <> clNone) then
          LForegroundColor := APaintVar^.LineForegroundColor
        else if ((eoShowSpecialChars in FOptions)
          and (LIsLineBreakToken or Assigned(LText) and CharInSet(AText^, [BCEDITOR_NONE_CHAR, BCEDITOR_TAB_CHAR, BCEDITOR_LINEFEED, BCEDITOR_CARRIAGE_RETURN, BCEDITOR_SPACE_CHAR]))) then
          if (FColors.SpecialChars.Foreground <> clNone) then
            LForegroundColor := FColors.SpecialChars.Foreground
          else
            LForegroundColor := clGrayText
        else if (Assigned(AToken) and Assigned(AToken^.Attribute) and (AToken^.Attribute.Foreground <> clNone)) then
          LForegroundColor := AToken^.Attribute.Foreground
        else if (Font.Color <> clNone) then
          LForegroundColor := Font.Color
        else
          LForegroundColor := clWindowText;

        if (not Assigned(APaintVar)) then
          LBackgroundColor := clNone
        else if (APaintVar^.LineBackgroundColor <> clNone) then
          LBackgroundColor := APaintVar^.LineBackgroundColor
        else if ((eoHighlightActiveLine in FOptions)
          and (ALinesPosition.Line = FLines.CaretPosition.Line)
          and (Colors.ActiveLine.Background <> clNone)) then
          LBackgroundColor := Colors.ActiveLine.Background
        else if (Assigned(AToken) and Assigned(AToken^.Attribute) and (AToken^.Attribute.Background <> clNone)) then
          LBackgroundColor := AToken^.Attribute.Background
        else if (Color <> clNone) then
          LBackgroundColor := Color
        else
          LBackgroundColor := clWindow;

        if (not LIsLineBreakToken
          or (soHighlightWholeLine in FSelectionOptions)) then
        begin
          if (FLines.SyncEdit
            and (FLines.SyncEditArea.BeginPosition < FLines.SyncEditArea.EndPosition)) then
            ApplyPart(FLines.SyncEditArea, ptSyncEdit);

          if ((esHighlightSearchAllAreas in FState)
            and (APaintVar^.SearchResultIndex < FLines.FoundAreas.Count)) then
            repeat
              if ((ALinesPosition <= FLines.FoundAreas[APaintVar^.SearchResultIndex].BeginPosition)
                or (FLines.FoundAreas[APaintVar^.SearchResultIndex].EndPosition < LEndPosition)) then
                ApplyPart(FLines.FoundAreas[APaintVar^.SearchResultIndex], ptSearchResult);

              if (FLines.FoundAreas[APaintVar^.SearchResultIndex].EndPosition <= LEndPosition) then
                Inc(APaintVar^.SearchResultIndex)
              else
                break;
            until ((APaintVar^.SearchResultIndex = FLines.FoundAreas.Count)
              or (FLines.FoundAreas[APaintVar^.SearchResultIndex].BeginPosition > LEndPosition));

          ApplyPart(FLines.MatchedPairOpenArea, ptMatchingPair);
          ApplyPart(FLines.MatchedPairCloseArea, ptMatchingPair);

          if (not APaintVar^.SelArea.IsEmpty()) then
            ApplyPart(APaintVar^.SelArea, ptSelection);

          if (APaintVar^.Parts.Count > 0) then
            CompleteParts();
        end;


        LBorderColor := clNone;
        LAddOnColor := clNone;
        LPartForegroundColor := LForegroundColor;
        LPartBackgroundColor := LBackgroundColor;

        LPartIndex := 0;
        repeat
          if (APaintVar^.Parts.Count = 0) then
          begin
            LPartText := LText;
            LPartLength := LLength;
          end
          else
          begin
            if (LPartIndex > 0) then
              LRect.Left := LRect.Right;

            LPartText := @LText[APaintVar^.Parts[LPartIndex].BeginPosition.Char - ALinesPosition.Char];
            LPartLength := APaintVar^.Parts[LPartIndex].EndPosition.Char - APaintVar^.Parts[LPartIndex].BeginPosition.Char;

            case (APaintVar^.Parts[LPartIndex].PartType) of
              ptNormal:
                begin
                  LPartForegroundColor := LForegroundColor;
                  LPartBackgroundColor := LBackgroundColor;
                end;
              ptSyncEdit:
                begin
                  LPartForegroundColor := LForegroundColor;
                  if (Colors.SyncEdit.Background <> clNone) then
                    LPartBackgroundColor := Colors.SyncEdit.Background;
                end;
              ptMatchingPair:
                begin
                  LPartForegroundColor := LForegroundColor;
                  if (FColors.MatchingPairs.Background <> clNone) then
                    LPartBackgroundColor := FColors.MatchingPairs.Background
                  else
                    LPartBackgroundColor := LBackgroundColor;
                end;
              ptSelection:
                begin
                  if (not Focused() and HideSelection) then
                    LPartForegroundColor := clWindowText
                  else if (FColors.Selection.Foreground <> clNone) then
                    LPartForegroundColor := FColors.Selection.Foreground
                  else
                    LPartForegroundColor := clHighlightText;
                  if (not Focused() and HideSelection) then
                    LPartBackgroundColor := cl3DLight
                  else if (FColors.Selection.Background <> clNone) then
                    LPartBackgroundColor := FColors.Selection.Background
                  else
                    LPartBackgroundColor := clHighlight;
                end;
              ptSearchResult:
                begin
                  if (FColors.FoundText.Foreground <> clNone) then
                    LPartForegroundColor := FColors.FoundText.Foreground
                  else
                    LPartForegroundColor := LForegroundColor;
                  if (FColors.FoundText.Background <> clNone) then
                    LPartBackgroundColor := FColors.FoundText.Background
                  else
                    LPartBackgroundColor := LBackgroundColor;
                end;
              else raise ERangeError.Create('PartType: ' + IntToStr(Ord(APaintVar^.Parts[LPartIndex].PartType)));
            end;

            if (LIsTabToken) then
              // Tab-Tokens have one part only - and they are computed before
            else if (LIsLineBreakToken) then
              // LineBreak-Tokens have one part only - and they are computed before
            else if (not Assigned(AText)) then
              // ... rest of the line
            else
              LRect.Right := LRect.Left + APaintHelper.TextWidth(LPartText, LPartLength);
          end;

          APaintHelper.ForegroundColor := LPartForegroundColor;
          APaintHelper.BackgroundColor := LPartBackgroundColor;

          LLeft := LRect.Left;
          if (LRect.Left < FLeftMarginWidth) then
          begin
            LRect.Left := FLeftMarginWidth;
            LOptions := ETO_CLIPPED;
          end
          else
            LOptions := 0;
          if (csOpaque in ControlStyle) then
            LOptions := LOptions or ETO_OPAQUE;

          if (LRect.Left <= LRect.Right) then
          begin
            if (LIsTabToken) then
              APaintHelper.ExtTextOut(LLeft + (LRect.Width - FTabSignWidth) div 2, LRect.Top,
                LOptions, LRect, LPartText, LPartLength, nil)
            else if (LIsLineBreakToken or not Assigned(AText)) then
              APaintHelper.ExtTextOut(LLeft, LRect.Top,
                LOptions, LRect, LPartText, LPartLength, nil)
            else if (not (fsItalic in LFontStyles)) then
              APaintHelper.ExtTextOut(LLeft, LRect.Top,
                LOptions, LRect, LPartText, LPartLength, nil)
            else if (not (fsItalic in APaintVar^.PreviousFontStyles)
              or (LPartBackgroundColor <> APaintVar^.PreviousBackgroundColor)
              or (APaintVar^.PreviousBackgroundColor = clNone)) then
              APaintHelper.ExtTextOut(LLeft, LRect.Top,
                LOptions, Rect(LRect.Left, LRect.Top, ARect.Right, LRect.Bottom), LPartText, LPartLength, nil)
            else
              APaintHelper.ExtTextOut(LLeft, LRect.Top,
                LOptions and not ETO_OPAQUE, LRect, LPartText, LPartLength, nil);

            if (FUCCVisible and APaintVar^.PreviousUCC) then
            begin
              APaintVar^.Graphics.FillRectangle(APaintVar^.UCCBrush, LRect.Left, LRect.Top, GLineWidth, FLineHeight);
              if (LIsTabToken) then
                APaintHelper.ExtTextOut(LLeft + (LRect.Width - FTabSignWidth) div 2, LRect.Top,
                  0, LRect, LPartText, 1, nil)
              else
                APaintHelper.ExtTextOut(LLeft, LRect.Top,
                  0, LRect, LPartText, 1, nil);
            end;

            APaintVar^.PreviousBackgroundColor := LPartBackgroundColor;
            APaintVar^.PreviousFontStyles := LFontStyles;
          end;

          Inc(LPartIndex);
        until ((APaintVar^.Parts.Count = 0) or (LPartIndex = APaintVar^.Parts.Count));

        APaintVar^.PreviousUCC := False;
        APaintVar^.Parts.Clear();

        if (Assigned(LText) and (LLength > 0) and not LIsUCCToken) then
          while ((APaintVar^.OverlayIndex < FOverlays.Count)
            and ((FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Line < ALinesPosition.Line)
              or (FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Line = ALinesPosition.Line)
                and (FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Char <= ALinesPosition.Char + LLength))) do
          begin
            if ((FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Line = ALinesPosition.Line)
              and (ALinesPosition.Char < FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Char)) then
            begin
              LOverlayBeginChar := Max(FOverlays[APaintVar^.OverlayIndex].Area.BeginPosition.Char, ALinesPosition.Char);
              LOverlayEndChar := Min(FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Char, ALinesPosition.Char + LLength);
              if ((ALinesPosition.Char <= LOverlayBeginChar) and (LOverlayEndChar <= ALinesPosition.Char + LLength)) then
              begin
                if (LOverlayBeginChar - ALinesPosition.Char = 0) then
                  LLeft := LRect.Left
                else
                  LLeft := LRect.Left + APaintHelper.TextWidth(LText, LOverlayBeginChar - ALinesPosition.Char);
                if (LOverlayEndChar - ALinesPosition.Char = ALength) then
                  LRight := LRect.Right
                else
                  LRight := LRect.Left + APaintHelper.TextWidth(LText, LOverlayEndChar - ALinesPosition.Char);
                case (FOverlays[APaintVar^.OverlayIndex].Style) of
                  osRect:
                    begin
                      if ((FOverlays[APaintVar^.OverlayIndex].Area.BeginPosition.Char >= ALinesPosition.Char)
                        and (LLeft >= LRect.Left)) then
                        APaintVar^.Graphics.FillRectangle(APaintVar^.OverlayRectBrush, LLeft, LRect.Top, GLineWidth, FLineHeight);
                      APaintVar^.Graphics.FillRectangle(APaintVar^.OverlayRectBrush, LLeft, LRect.Top, LRight - LLeft, GLineWidth);
                      APaintVar^.Graphics.FillRectangle(APaintVar^.OverlayRectBrush, LLeft, LRect.Bottom - GLineWidth, LRight - LLeft, GLineWidth);
                      if (FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Char <= ALinesPosition.Char + LLength) then
                        APaintVar^.Graphics.FillRectangle(APaintVar^.OverlayRectBrush, LRight - GLineWidth, LRect.Top, GLineWidth, FLineHeight);
                    end;
                  osUnderline:
                    begin
                      APaintVar^.Graphics.FillRectangle(APaintVar^.OverlayUnderlineBrush, LLeft, LRect.Bottom - 2 * GLineWidth, LRight - LLeft, GLineWidth);
                    end;
//                  osWaveLine:
//                    begin
//                      LStep := 0;
//                      while LStep < ARect.Right - 4 do
//                      begin
//                        Canvas.MoveTo(ARect.Left + LStep, ARect.Bottom - 3);
//                        Canvas.LineTo(ARect.Left + LStep + 2, ARect.Bottom - 1);
//                        Canvas.LineTo(ARect.Left + LStep + 4, ARect.Bottom - 3);
//                        Inc(LStep, 4);
//                      end;
//                    end;
                end;
              end;
            end;
            if ((FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Line < ALinesPosition.Line)
              or (FOverlays[APaintVar^.OverlayIndex].Area.EndPosition.Char <= ALinesPosition.Char + LLength)) then
              Inc(APaintVar^.OverlayIndex)
            else
              break;
          end;

        if (Assigned(ARange)
          and (LCollapsedMarkRect.Right >= ARect.Left)
          and (LCollapsedMarkRect.Left < ARect.Right)) then
        begin
          APaintHelper.FrameRect(LCollapsedMarkRect, FColors.CodeFolding.Foreground);
          APaintHelper.ForegroundColor := FColors.CodeFolding.Foreground;
          APaintHelper.ExtTextOut(LCollapsedMarkRect.Left, LCollapsedMarkRect.Top,
            0, LCollapsedMarkRect, BCEDITOR_CODEFOLDING_COLLAPSEDMARK, Length(BCEDITOR_CODEFOLDING_COLLAPSEDMARK), nil);
        end;

        if ((FState * [esCaretInvalid] <> [])
          and (ALinesPosition.Line = FLines.CaretPosition.Line)
          and (ALinesPosition.Char <= FLines.CaretPosition.Char) and (FLines.CaretPosition.Char < ALinesPosition.Char + ALength)) then
        begin
          LLength := FLines.CaretPosition.Char - ALinesPosition.Char;
          if (LLength = 0) then
            FCaretPos := Point(ARect.Left, ARect.Top)
          else
            FCaretPos := Point(ARect.Left + APaintHelper.TextWidth(LText, LLength), ARect.Top);
        end;

        if (Assigned(APaintVar)) then
          APaintVar^.PreviousUCC := LIsUCCToken;
      end;
    cjMouseDown,
    cjMouseDblClk,
    cjMouseMove,
    cjMouseUp,
    cjHint:
      if (LRect.Contains(AMousePoint)
        and (MouseCapture in [mcNone, mcText])
        and (not LIsLineBreakToken or (ALinesPosition.Line < FLines.Count - 1))) then
      begin
        LLine := ALinesPosition.Line;
        if (not Assigned(AText)) then
        begin
          if (not (eoBeyondEndOfFile in FOptions) and (ALinesPosition.Line >= FLines.Count)) then
            LLine := Max(0, FLines.Count - 1);
          if (not (eoBeyondEndOfLine in FOptions)) then
            LChar := 0
          else
            LChar := (AMousePoint.X + FSpaceWidth div 2 - LRect.Left) div FSpaceWidth;
        end
        else if (LIsTabToken) then
          if (AMousePoint.X <= LRect.Left + (LRect.Right - LRect.Left) div 2) then
            LChar := 0
          else
            LChar := 1
        else
        begin
          LChar := 1;
          while (AMousePoint.X >= LRect.Left + APaintHelper.TextWidth(LText, LChar)) do
            Inc(LChar);
          if (AMousePoint.X <= LRect.Left + APaintHelper.TextWidth(LText, LChar - 1) + APaintHelper.TextWidth(@LText[LChar - 1], 1) div 2) then
            Dec(LChar);
        end;

        LCursorPosition := LinesPosition(ALinesPosition.Char + LChar, LLine);
        case (AJob) of
          cjMouseDown:
            if (AButton = mbLeft) then
              if (FLines.SelArea.Contains(LCursorPosition)) then
              begin
                Include(FState, esWaitForDrag);
                FLastDoubleClickTime := 0;
              end
              else if (LCollapsedMarkRect.Contains(AMousePoint)) then
              begin
                ProcessCommand(ecPosition, TBCEditorCommandDataPosition.Create(FLines.EOLPosition[ALinesPosition.Line], ssShift in AShift));
                MouseCapture := mcText;
              end
              else
              begin
                ProcessCommand(ecPosition, TBCEditorCommandDataPosition.Create(LCursorPosition, ssShift in AShift));
                MouseCapture := mcText;
              end;
          cjMouseDblClk:
            if (LRect.Contains(AMousePoint)
              and (AButton = mbLeft)
              and (not LIsLineBreakToken or (ALinesPosition.Line < FLines.Count - 1))) then
              if (LCollapsedMarkRect.Contains(AMousePoint)) then
              begin
                ExpandCodeFoldingRange(ARange);
                SetCaretPos(FLines.EOLPosition[ALinesPosition.Line]);
                FLastDoubleClickTime := 0;
              end
              else
                SetWordBlock(LCursorPosition);
          cjMouseMove:
            begin
              if (LCollapsedMarkRect.Contains(AMousePoint)) then
                Cursor := crDefault
              else
                Cursor := crIBeam;
              if (AShift * [ssLeft, ssRight, ssMiddle] = [ssLeft]) then
                if (not (esWaitForDrag in FState)) then
                begin
                  if ((MouseCapture = mcText)
                    and not (esMouseDblClk in FState)) then
                    ProcessCommand(ecPosition, TBCEditorCommandDataPosition.Create(LCursorPosition, True));
                end
                else if ((Abs(FMouseDownPoint.X - AMousePoint.X) >= GetSystemMetrics(SM_CXDRAG))
                  or (Abs(FMouseDownPoint.Y - AMousePoint.Y) >= GetSystemMetrics(SM_CYDRAG))) then
                begin
                  Exclude(FState, esWaitForDrag);
                  Include(FState, esDragging);
                  try
                    LSelStartBefore := SelStart;
                    LSelLength := SelLength;
                    if (Succeeded(DoDragDrop(TDropData.Create(Self), Self, DROPEFFECT_COPY or DROPEFFECT_MOVE, LEffect))
                      and (LEffect = DROPEFFECT_MOVE)) then
                    begin
                      LSelStartAfter := SelStart;
                      BeginUpdate();
                      try
                        if (LSelStartBefore < LSelStartAfter) then
                        begin
                          LArea.BeginPosition := FLines.PositionOf(LSelStartBefore);
                          LArea.EndPosition := FLines.PositionOf(LSelLength, LArea.BeginPosition);
                          FLines.DeleteText(LArea);
                          LSelArea.BeginPosition := FLines.PositionOf(LSelStartAfter - LSelLength);
                          LSelArea.EndPosition := FLines.PositionOf(LSelLength, LSelArea.BeginPosition);
                        end
                        else
                        begin
                          LSelArea := FLines.SelArea;
                          LArea.BeginPosition := FLines.PositionOf(LSelStartBefore + SelLength);
                          LArea.EndPosition := FLines.PositionOf(LSelLength, LArea.BeginPosition);
                          FLines.DeleteText(LArea);
                        end;
                        SetSelArea(LSelArea);
                      finally
                        EndUpdate();
                      end;
                    end;
                  finally
                    Exclude(FState, esDragging);
                  end;
                end;
            end;
          cjMouseUp:
            if (LCollapsedMarkRect.Contains(AMousePoint)) then
            else
            begin
              if ((AButton = mbLeft)
                and (esWaitForDrag in FState)) then
              begin
                ProcessCommand(ecPosition, TBCEditorCommandDataPosition.Create(LCursorPosition, ssShift in AShift));
                Exclude(FState, esWaitForDrag);
              end;
            end;
          cjHint:
            if (LCollapsedMarkRect.Contains(AMousePoint)) then
              ActivateHint(AMousePoint.X, AMousePoint.Y + FLineHeight,
                Format(SBCEditorCodeFoldingCollapsedMark, [ARange.EndLine - ARange.BeginLine]))
            else if (LRect.Contains(AMousePoint)) then
              if (Assigned(FOnHint)) then
              begin
                FOnHint(Self,
                  LRect.Left, LRect.Top + FLineHeight,
                  Point(ALinesPosition.Char + LChar, ALinesPosition.Line),
                  FLines.CharIndexOf(LinesPosition(ALinesPosition.Char + LChar, ALinesPosition.Line)),
                  LHint);
                Result := LHint <> '';
                if (Result) then
                  ActivateHint(LRect.Left, LRect.Top + FLineHeight, LHint);
              {$IFDEF Nils}
              end
              else if (Assigned(AToken)) then
              begin
                LHint := 'Position: ' + LCursorPosition.ToString() + #10;
                LHint := LHint + 'Area: ' + ALinesPosition.ToString() + ' - ' + LinesPosition(ALinesPosition.Char + ALength - 1, ALinesPosition.Line).ToString() + #10;
                if (Assigned(AToken.Attribute) and (AToken.Attribute.Element <> BCEDITOR_ATTRIBUTE_ELEMENT_EDITOR)) then
                  LHint := LHint + 'Element: ' + AToken.Attribute.Element + #10;
                if (FLines.ValidPosition(LCursorPosition) and IsWordBreakChar(FLines.Char[LCursorPosition])) then
                  LHint := LHint + 'IsWordBreakChar: True' + #10;
                LHint := Trim(LHint);
                ActivateHint(LRect.Left, LRect.Top + FLineHeight, Trim(LHint));
              {$ENDIF}
              end;
        end;
        Result := True;
      end;
  end;

  if (Assigned(ARange)) then
    ARect.Left := Max(ARect.Left, LCollapsedMarkRect.Right)
  else if (not LIsLineBreakToken) then
    ARect.Left := Max(ARect.Left, LRect.Right)
  else if (eoShowSpecialChars in FOptions) then
    ARect.Left := Max(ARect.Left, LRect.Left + FLineBreakSignWidth);
end;

function TCustomBCEditor.QueryContinueDrag(fEscapePressed: BOOL; grfKeyState: Longint): HResult;
begin
  if (fEscapePressed) then
    Result := DRAGDROP_S_CANCEL
  else if (grfKeyState and MK_LBUTTON = 0) then
    Result := DRAGDROP_S_DROP
  else
    Result := S_OK;
end;

procedure TCustomBCEditor.ReadState(Reader: TReader);
begin
  inherited;

  if (eoTrimTrailingLines in Options) then
    FLines.Options := FLines.Options + [loTrimTrailingLines]
  else
    FLines.Options := FLines.Options - [loTrimTrailingLines];
  if (eoTrimTrailingSpaces in Options) then
    FLines.Options := FLines.Options + [loTrimTrailingSpaces]
  else
    FLines.Options := FLines.Options - [loTrimTrailingSpaces];
end;

procedure TCustomBCEditor.Redo();
begin
  ProcessCommand(ecRedo);
end;

procedure TCustomBCEditor.RegisterCommandHandler(const AProc: Pointer;
  const AHandlerData: Pointer);
var
  LCommandHandler: TBCEditorHookedCommandHandler;
begin
  if (Assigned(AProc)) then
  begin
    FillChar(LCommandHandler, SizeOf(LCommandHandler), 0);
    LCommandHandler.Proc := AProc;
    LCommandHandler.HandlerData := AHandlerData;
    if (FHookedCommandHandlers.IndexOf(LCommandHandler) < 0) then
      FHookedCommandHandlers.Add(LCommandHandler);
  end;
end;

procedure TCustomBCEditor.RegisterCommandHandler(const AProc: TBCEditorHookedCommandObjectProc);
var
  LCommandHandler: TBCEditorHookedCommandHandler;
begin
  if (Assigned(AProc)) then
  begin
    FillChar(LCommandHandler, SizeOf(LCommandHandler), 0);
    LCommandHandler.ObjectProc := AProc;
    if (FHookedCommandHandlers.IndexOf(LCommandHandler) < 0) then
      FHookedCommandHandlers.Add(LCommandHandler);
  end;
end;

procedure TCustomBCEditor.ReplaceDialogFind(ASender: TObject);
var
  LOptions: TBCEditorFindOptions;
begin
  LOptions := LOptions - [foRegExpr];
  if (frDown in TReplaceDialog(ASender).Options) then
    LOptions := LOptions - [foBackwards]
  else
    LOptions := LOptions + [foBackwards];
  if (frMatchCase in TReplaceDialog(ASender).Options) then
    LOptions := LOptions + [foCaseSensitive]
  else
    LOptions := LOptions - [foCaseSensitive];
  LOptions := LOptions - [foEntireScope];
  if (frWholeWord in TReplaceDialog(ASender).Options) then
    LOptions := LOptions + [foWholeWordsOnly]
  else
    LOptions := LOptions - [foWholeWordsOnly];

  FLastSearch := lsFind;
  FLastSearchData := TBCEditorCommandDataFind.Create(TReplaceDialog(ASender).FindText, LOptions);
  ProcessCommand(ecFindFirst, FLastSearchData);
end;

procedure TCustomBCEditor.ReplaceDialogReplace(ASender: TObject);
var
  LOptions: TBCEditorReplaceOptions;
begin
  LOptions := LOptions - [roBackwards, roRegExpr];
  if (frMatchCase in TReplaceDialog(ASender).Options) then
    LOptions := LOptions + [roCaseSensitive]
  else
    LOptions := LOptions - [roCaseSensitive];
  LOptions := LOptions - [roEntireScope];
  LOptions := LOptions - [roPrompt];
  if (frReplaceAll in TReplaceDialog(ASender).Options) then
    LOptions := LOptions + [roReplaceAll]
  else
    LOptions := LOptions - [roReplaceAll];
  if (FLines.SelArea.IsEmpty()) then
    LOptions := LOptions - [roSelection]
  else
    LOptions := LOptions + [roSelection];
  if (frWholeWord in TReplaceDialog(ASender).Options) then
    LOptions := LOptions + [roWholeWordsOnly]
  else
    LOptions := LOptions - [roWholeWordsOnly];

  FLastSearch := lsReplace;
  FLastSearchData := TBCEditorCommandDataReplace.Create(TReplaceDialog(ASender).FindText, TReplaceDialog(ASender).ReplaceText, LOptions);
  ProcessCommand(ecReplace, FLastSearchData);
end;

procedure TCustomBCEditor.ReplaceExecuted(const AData: Pointer);
var
  LSearchResult: TBCEditorLines.TSearchResult;
begin
  LSearchResult := TBCEditorLines.PSearchResult(AData)^;

  if (LSearchResult.Count > 0) then
    InvalidateClient();

  UpdateCursor();
end;

procedure TCustomBCEditor.Resize();
begin
  inherited;

  if (FWordWrap and (ClientRect.Width <> FOldClientRect.Width) and (FRows.Count > 0)) then
    InvalidateRows();

  UpdateMetrics();

  if (FLineHeight <> 0) then
  begin
    Include(FState, esCenterCaret);
    try
      ScrollToPosition(FLines.CaretPosition);
    finally
      Exclude(FState, esCenterCaret);
    end;
  end;

  Include(FState, esSizeChanged);
  InvalidateScrollBars();

  if (DoubleBuffered) then
    Perform(CM_DOUBLEBUFFEREDCHANGED, 0, 0);
end;

function TCustomBCEditor.RowsToClient(ARowsPosition: TBCEditorRowsPosition;
  const AVisibleOnly: Boolean = False): TPoint;
begin
  Result := RowsToText(ARowsPosition, AVisibleOnly);
  if (not InvalidPoint(Result)) then
    Result := Result - FTextPos + FMetrics.TextRect.TopLeft;
end;

function TCustomBCEditor.RowsToLines(const ARowsPosition: TBCEditorRowsPosition): TBCEditorLinesPosition;
var
  LChar: Integer;
  LColumn: Integer;
  LLine: Integer;
  LLineEndPos: PChar;
  LLinePos: PChar;
begin
  Assert((ARowsPosition.Column >= 0) and (ARowsPosition.Row >= 0));

  if (FRows.Count = 0) then
    Result := LinesPosition(ARowsPosition.Column, ARowsPosition.Row)
  else if (ARowsPosition.Row >= FRows.Count) then
    Result := LinesPosition(ARowsPosition.Column, ARowsPosition.Row - FRows.Count + FLines.Count)
  else
  begin
    LLine := FRows.Items[ARowsPosition.Row].Line;

    if (not (rfHasTabs in FRows.Items[ARowsPosition.Row].Flags)) then
    begin
      LChar := FRows.Items[ARowsPosition.Row].Char + ARowsPosition.Column;
      if (LChar >= Length(FLines[LLine])) then
      begin
        LLinePos := nil;
        LLineEndPos := nil;
      end
      else
      begin
        LLinePos := @FLines[LLine][1 + LChar];
        LLineEndPos := @FLines[LLine][Min(1 + FRows.Items[ARowsPosition.Row].Length, Length(FLines[LLine]))];
      end;
    end
    else
    begin
      LLinePos := @FLines[LLine][1 + FRows.Items[ARowsPosition.Row].Char];
      LLineEndPos := @FLines[LLine][Min(FRows.Items[ARowsPosition.Row].Length, Length(FLines[LLine]))];
      LColumn := 0;
      LChar := 0;
      while ((LColumn < ARowsPosition.Column) and (LLinePos < LLineEndPos)) do
      begin
        Inc(LColumn, TokenColumns(LLinePos, 1, LColumn));
        Inc(LChar);
        Inc(LLinePos);
      end;
      Inc(LChar, ARowsPosition.Column - LColumn);
    end;

    if (Assigned(LLinePos)) then
      while ((LLinePos <= LLineEndPos)
        and ((LLinePos^.GetUnicodeCategory in [TUnicodeCategory.ucCombiningMark, TUnicodeCategory.ucNonSpacingMark])
          or ((LLinePos - 1)^ <> BCEDITOR_NONE_CHAR)
            and ((LLinePos - 1)^.GetUnicodeCategory = TUnicodeCategory.ucNonSpacingMark)
            and not IsCombiningDiacriticalMark((LLinePos - 1)^))) do
      begin
        Inc(LChar);
        Inc(LLinePos);
      end;

    Result := LinesPosition(LChar, LLine);
  end;
end;

function TCustomBCEditor.RowsToText(ARowsPosition: TBCEditorRowsPosition;
  const AVisibleOnly: Boolean = False): TPoint;
var
  LBeginRange: TBCEditorHighlighter.TRange;
  LChar: Integer;
  LCharColumns: Integer;
  LColumn: Integer;
  LEOL: Boolean;
  LLeft: Integer;
  LLength: Integer;
  LLine: Integer;
  LLinePos: PChar;
  LRow: Integer;
  LRowColumns: Integer;
  LText: PChar;
  LToken: TBCEditorHighlighter.TTokenFind;
  LTokenColumns: Integer;
  LTokenWidth: Integer;
begin
  if (not AVisibleOnly) then
  begin
    Result := RowsToText(ARowsPosition, True);
    if (not InvalidPoint(Result)) then
      Exit;
  end;

  if ((FRows.Count = 0)
    or (ARowsPosition.Column = 0)
    or (ARowsPosition.Row >= FRows.Count)
    or (FRows.Items[ARowsPosition.Row].Length = 0)) then
    Result := Point(ARowsPosition.Column * FSpaceWidth, ARowsPosition.Row * FLineHeight)
  else if (ARowsPosition.Row = FRows.Items[ARowsPosition.Row].Length) then
    Result := Point(FRows.Items[ARowsPosition.Row].Width, ARowsPosition.Row * FLineHeight)
  else
  begin
    FPaintHelper.BeginDraw(Canvas.Handle);
    try
      LRow := ARowsPosition.Row;
      LLine := FRows.Items[LRow].Line;

      LRowColumns := 0;
      LTokenColumns := 0;

      LEOL := True;

      if (AVisibleOnly) then
        LLeft := Max(0, FTextPos.X - FMetrics.TextRect.Width)
      else
        LLeft := 0;
      if (GetFindTokenData(LRow, LLeft, LBeginRange, LText, LLength, LChar, LColumn)
        and FHighlighter.FindFirstToken(LBeginRange, LText, LLength, LChar, LToken)) then
      begin
        LRowColumns := LColumn;

        if (LRowColumns <= ARowsPosition.Column) then
          repeat
            LTokenColumns := TokenColumns(LToken.Text, LToken.Length, LColumn);
            LTokenWidth := TokenWidth(FPaintHelper, LLine, LToken.Text, LToken.Length, LColumn, @LToken);

            if (LRowColumns + LTokenColumns > ARowsPosition.Column) then
              LEOL := False;

            if (AVisibleOnly) then
              if (LRowColumns + LTokenColumns = ARowsPosition.Column) then
                Exit(Point(LLeft + LTokenWidth, ARowsPosition.Row * FLineHeight))
              else if (LLeft > FTextPos.X + 2 * FMetrics.TextRect.Width) then
                Exit(Point(-1, -1));

            if (LEOL) then
            begin
              Inc(LRowColumns, LTokenColumns);
              Inc(LLeft, LTokenWidth);
              Inc(LColumn, LTokenColumns);
            end;
          until (not LEOL or not FHighlighter.FindNextToken(LToken));

        FHighlighter.FindClose(LToken);
      end;

      if ((LRowColumns < ARowsPosition.Column) and (LTokenColumns > 0)
        and not LEOL) then
      begin
        LLinePos := LToken.Text;
        while ((LRowColumns < ARowsPosition.Column) and (LTokenColumns > 0)) do
        begin
          LCharColumns := TokenColumns(LLinePos, 1, LColumn);
          Inc(LRowColumns, LCharColumns);
          Inc(LLeft, TokenWidth(FPaintHelper, LLine, LLinePos, 1, LColumn, @LToken));
          Inc(LColumn, LCharColumns);
          Inc(LLinePos);
        end;
      end;

      if (LRowColumns < ARowsPosition.Column) then
        Inc(LLeft, (ARowsPosition.Column - LRowColumns) * FSpaceWidth);
    finally
      FPaintHelper.EndDraw();
    end;

    if (AVisibleOnly and LEOL) then
      Result := Point(-1, -1)
    else
      Result := Point(LLeft, ARowsPosition.Row * FLineHeight);
  end;
end;

procedure TCustomBCEditor.RowsWantedValid();
var
  LRect: TRect;
begin
  FBuildRowsCriticalSection.Enter();
  try
    case (FRowsWanted.What) of
      rwPaintText:
        begin
          LRect := Rect(
            0, (FRowsWanted.Row - FTopRow) * FLineHeight,
            FMetrics.TextRect.Right, FMetrics.TextRect.Bottom);
          InvalidateRect(LRect);
        end;
      rwScrollToPosition:
        begin
          if (FRowsWanted.CenterCaret) then
            Include(FState, esCenterCaret);
          try
            ScrollToPosition(FRowsWanted.Position);
          finally
            if (FRowsWanted.CenterCaret) then
              Exclude(FState, esCenterCaret);
          end;
        end;
      rwDown:
        DoUpOrDown(FRowsWanted.Row - FRows.CaretPosition.Row, FRowsWanted.Select);
      rwEOF:
        SetCaretPosition(FLines.EOFPosition, FRowsWanted.Select);
    end;
  finally
    FBuildRowsCriticalSection.Leave();
  end;

  FRowsWanted.What := rwNothing;
  UpdateCursor();
end;

procedure TCustomBCEditor.SaveToFile(const AFileName: string; AEncoding: TEncoding = nil);
var
  LFileStream: TFileStream;
begin
  LFileStream := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(LFileStream, AEncoding);
  finally
    LFileStream.Free;
  end;
end;

procedure TCustomBCEditor.SaveToStream(AStream: TStream; AEncoding: TEncoding = nil);
begin
  FLines.SaveToStream(AStream, AEncoding);
  SetModified(False);
end;

procedure TCustomBCEditor.ScanCodeFolding();
var
  LIndex: Integer;
  LLine: Integer;
  LRange: TBCEditorCodeFoldingRanges.TRange;
begin
  if (FLeftMargin.CodeFolding.Visible) then
  begin
    for LLine := 0 to FLines.Count - 1 do
    begin
      FLines.SetCodeFoldingBeginRange(LLine, nil);
      FLines.SetCodeFoldingEndRange(LLine, nil);
      FLines.SetCodeFoldingTreeLine(LLine, False);
    end;

    FAllCodeFoldingRanges.ClearAll();

    ScanCodeFoldingRanges();

    Exclude(FState, esCodeFoldingInvalid);

    for LIndex := FAllCodeFoldingRanges.AllCount - 1 downto 0 do
    begin
      LRange := FAllCodeFoldingRanges[LIndex];
      if (Assigned(LRange)
        and not LRange.ParentCollapsed
        and ((LRange.BeginLine <> LRange.EndLine)
          or LRange.RegionItem.TokenEndIsPreviousLine)) then
      begin
        FLines.SetCodeFoldingBeginRange(LRange.BeginLine, LRange);

        if LRange.Collapsable then
        begin
          for LLine := LRange.BeginLine + 1 to LRange.EndLine - 1 do
            FLines.SetCodeFoldingTreeLine(LLine, True);

          FLines.SetCodeFoldingEndRange(LRange.EndLine, LRange);
        end;
      end;
    end;

    if (FLeftMargin.CodeFolding.Visible) then
      InvalidateRect(FMetrics.CodeFoldingRect);
  end;
end;

procedure TCustomBCEditor.ScanCodeFoldingRanges;
const
  DEFAULT_CODE_FOLDING_RANGE_INDEX = 0;
var
  LBeginningOfLine: Boolean;
  LCodeFoldingRangeIndexList: TList;
  LCurrentCodeFoldingRegion: TBCEditorCodeFoldingRegion;
  LFoldCount: Integer;
  LFoldRanges: TBCEditorCodeFoldingRanges;
  LLastFoldRange: TBCEditorCodeFoldingRanges.TRange;
  LLine: Integer;
  LLineEndPos: PChar;
  LLinePos: PChar;
  LOpenTokenFoldRangeList: TList;
  LOpenTokenSkipFoldRangeList: TList;
  LPBookmarkText: PChar;
  LPBookmarkText2: PChar;

  function IsValidChar(Character: PChar): Boolean;
  begin
    Result := Character^.IsLower or Character^.IsUpper or Character^.IsNumber or
      CharInSet(Character^, BCEDITOR_CODE_FOLDING_VALID_CHARACTERS);
  end;

  function IsWholeWord(FirstChar, LastChar: PChar): Boolean;
  begin
    Result := not IsValidChar(FirstChar) and not IsValidChar(LastChar);
  end;

  function SkipEmptySpace(): Boolean;
  begin
    while ((LLinePos <= LLineEndPos) and (LLinePos^ < BCEDITOR_EXCLAMATION_MARK)) do
      Inc(LLinePos);
    Result := LLinePos > LLineEndPos;
  end;

  function CountCharsBefore(APText: PChar; const Character: Char): Integer;
  var
    LPText: PChar;
  begin
    Result := 0;
    LPText := APText - 1;
    while LPText^ = Character do
    begin
      Inc(Result);
      Dec(LPText);
    end;
  end;

  function OddCountOfStringEscapeChars(APText: PChar): Boolean;
  begin
    Result := False;
    if LCurrentCodeFoldingRegion.StringEscapeChar <> BCEDITOR_NONE_CHAR then
      Result := Odd(CountCharsBefore(APText, LCurrentCodeFoldingRegion.StringEscapeChar));
  end;

  function EscapeChar(APText: PChar): Boolean;
  begin
    Result := False;
    if LCurrentCodeFoldingRegion.EscapeChar <> BCEDITOR_NONE_CHAR then
      Result := APText^ = LCurrentCodeFoldingRegion.EscapeChar;
  end;

  function IsNextSkipChar(APText: PChar; ASkipRegionItem: TBCEditorCodeFoldingSkipRegions.TItem): Boolean;
  begin
    Result := False;
    if ASkipRegionItem.SkipIfNextCharIsNot <> BCEDITOR_NONE_CHAR then
      Result := APText^ = ASkipRegionItem.SkipIfNextCharIsNot;
  end;

  function SkipRegionsClose: Boolean;
  var
    LSkipRegionItem: TBCEditorCodeFoldingSkipRegions.TItem;
    LTokenEndPos: PChar;
    LTokenPos: PChar;
    LTokenText: string;
  begin
    Result := False;
    { Note! Check Close before Open because close and open keys might be same. }
    if ((LOpenTokenSkipFoldRangeList.Count > 0)
      and CharInSet(LLinePos^, FHighlighter.SkipCloseKeyChars)
      and not OddCountOfStringEscapeChars(LLinePos)) then
    begin
      LSkipRegionItem := LOpenTokenSkipFoldRangeList.Last;
      if (LSkipRegionItem.CloseToken <> LSkipRegionItem.CloseToken) then
      begin
        LTokenText := LSkipRegionItem.CloseToken;
        LTokenPos := @LTokenText[1];
        LTokenEndPos := @LTokenText[Length(LTokenText)];
        LPBookmarkText := LLinePos;
        { Check if the close keyword found }
        while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
          and ((LLinePos^ = LTokenPos^) or (LSkipRegionItem.SkipEmptyChars and (LLinePos^ < BCEDITOR_EXCLAMATION_MARK)))) do
        begin
          if (not CharInSet(LLinePos^, [BCEDITOR_NONE_CHAR, BCEDITOR_SPACE_CHAR, BCEDITOR_TAB_CHAR])) then
            Inc(LTokenPos);
          Inc(LLinePos);
        end;
        if (LTokenPos >= LTokenEndPos) then { If found, pop skip region from the stack }
        begin
          LOpenTokenSkipFoldRangeList.Delete(LOpenTokenSkipFoldRangeList.Count - 1);
          Result := True;
        end
        else
          LLinePos := LPBookmarkText; { Skip region close not found, return pointer back }
      end;
    end;
  end;

  function SkipRegionsOpen: Boolean;
  var
    LCount: Integer;
    LIndex: Integer;
    LSkipRegionItem: TBCEditorCodeFoldingSkipRegions.TItem;
    LTokenEndPos: PChar;
    LTokenPos: PChar;
    LTokenText: string;
  begin
    Result := False;

    if CharInSet(LLinePos^, FHighlighter.SkipOpenKeyChars) then
      if LOpenTokenSkipFoldRangeList.Count = 0 then
      begin
        LCount := LCurrentCodeFoldingRegion.SkipRegions.Count - 1;
        for LIndex := 0 to LCount do
        begin
          LSkipRegionItem := LCurrentCodeFoldingRegion.SkipRegions[LIndex];
          if ((LLinePos^ = LSkipRegionItem.OpenToken[1])
            and not OddCountOfStringEscapeChars(LLinePos)
            and not IsNextSkipChar(LLinePos + Length(LSkipRegionItem.OpenToken), LSkipRegionItem)) then
          begin
            LTokenText := LSkipRegionItem.OpenToken;
            if (LTokenText <> '') then
            begin
              LTokenPos := @LTokenText[1];
              LTokenEndPos := @LTokenText[Length(LTokenText)];
              LPBookmarkText := LLinePos;
              { Check, if the open keyword found }
              while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
                and ((LLinePos^ = LTokenPos^) or (LSkipRegionItem.SkipEmptyChars and (LLinePos^ < BCEDITOR_EXCLAMATION_MARK)))) do
              begin
                if (not LSkipRegionItem.SkipEmptyChars
                  or LSkipRegionItem.SkipEmptyChars and not CharInSet(LLinePos^, [BCEDITOR_NONE_CHAR, BCEDITOR_SPACE_CHAR, BCEDITOR_TAB_CHAR])) then
                  Inc(LTokenPos);
                Inc(LLinePos);
              end;

              if (LTokenPos > LTokenEndPos) then { If found, skip single line comment or push skip region into stack }
              begin
                if LSkipRegionItem.RegionType = ritSingleLineString then
                begin
                  LTokenText := LSkipRegionItem.CloseToken;
                  if (LTokenText <> '') then
                  begin
                    LTokenPos := @LTokenText[1];
                    LTokenEndPos := @LTokenText[Length(LTokenText)];
                    while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
                      and ((LLinePos^ <> LTokenPos^) or OddCountOfStringEscapeChars(LLinePos))) do
                      Inc(LLinePos);
                    Inc(LLinePos);
                  end;
                end
                else if LSkipRegionItem.RegionType = ritSingleLineComment then
                  { Single line comment skip until next line }
                  Exit(True)
                else
                  LOpenTokenSkipFoldRangeList.Add(LSkipRegionItem);
                Dec(LLinePos); { The end of the while loop will increase }
                Break;
              end
              else
                LLinePos := LPBookmarkText; { Skip region open not found, return pointer back }
            end;
          end;
        end;
      end;
  end;

  procedure RegionItemsClose;

    procedure SetCodeFoldingRangeToLine(ARange: TBCEditorCodeFoldingRanges.TRange);
    var
      LIndex: Integer;
    begin
      if ARange.RegionItem.TokenEndIsPreviousLine then
      begin
        LIndex := LLine;
        while (LIndex > 0) and (FLines.Items[LIndex - 1].Text = '') do
          Dec(LIndex);
        ARange.EndLine := LIndex
      end
      else
        ARange.EndLine := LLine;
    end;

  var
    LCodeFoldingRange: TBCEditorCodeFoldingRanges.TRange;
    LCodeFoldingRangeLast: TBCEditorCodeFoldingRanges.TRange;
    LIndex: Integer;
    LIndexDecrease: Integer;
    LItemIndex: Integer;
    LTokenEndPos: PChar;
    LTokenPos: PChar;
    LTokenText: string;
  begin
    if ((LOpenTokenSkipFoldRangeList.Count = 0) 
      and (LOpenTokenFoldRangeList.Count > 0)
      and CharInSet(UpCase(LLinePos^), FHighlighter.FoldCloseKeyChars)) then
    begin
      LIndexDecrease := 1;
      {$if defined(VER250)}
      LCodeFoldingRange := nil;
      {$endif}
      repeat
        LIndex := LOpenTokenFoldRangeList.Count - LIndexDecrease;
        if LIndex < 0 then
          Break;
        LCodeFoldingRange := LOpenTokenFoldRangeList.Items[LIndex];

        if LCodeFoldingRange.RegionItem.CloseTokenBeginningOfLine and not LBeginningOfLine then
          Exit;
        LTokenText := LCodeFoldingRange.RegionItem.CloseToken;
        if (LTokenText <> '') then
        begin
          LTokenPos := @LTokenText[1];
          LTokenEndPos := @LTokenText[Length(LTokenText)];
          LPBookmarkText := LLinePos;
          { Check if the close keyword found }
          while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
            and (UpCase(LLinePos^) = LTokenPos^)) do
          begin
            Inc(LLinePos);
            Inc(LTokenPos);
          end;

          if (LTokenPos > LTokenEndPos) then { If found, pop skip region from the stack }
          begin
            if not LCodeFoldingRange.RegionItem.BreakCharFollows or
              LCodeFoldingRange.RegionItem.BreakCharFollows and IsWholeWord(LPBookmarkText - 1, LLinePos) then
            begin
              LOpenTokenFoldRangeList.Remove(LCodeFoldingRange);
              Dec(LFoldCount);

              if ((LCodeFoldingRange.RegionItem.BreakIfNotFoundBeforeNextRegion <> '')
                and not LCodeFoldingRange.IsExtraTokenFound) then
              begin
                LLinePos := LPBookmarkText;
                Exit;
              end;
              SetCodeFoldingRangeToLine(LCodeFoldingRange);
              { Check if the code folding ranges have shared close }
              if LOpenTokenFoldRangeList.Count > 0 then
                for LItemIndex := LOpenTokenFoldRangeList.Count - 1 downto 0 do
                begin
                  LCodeFoldingRangeLast := LOpenTokenFoldRangeList.Items[LItemIndex];
                  if Assigned(LCodeFoldingRangeLast.RegionItem) and LCodeFoldingRangeLast.RegionItem.SharedClose then
                  begin
                    LTokenText := LCodeFoldingRangeLast.RegionItem.CloseToken;
                    LTokenPos := @LTokenText[1];
                    LTokenEndPos := @LTokenText[Length(LTokenText)];
                    LLinePos := LPBookmarkText;
                    while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
                      and (UpCase(LLinePos^) = LTokenPos^)) do
                    begin
                      Inc(LLinePos);
                      Inc(LTokenPos);
                    end;
                    if (LTokenPos > LTokenEndPos) then
                    begin
                      SetCodeFoldingRangeToLine(LCodeFoldingRangeLast);
                      LOpenTokenFoldRangeList.Remove(LCodeFoldingRangeLast);
                      Dec(LFoldCount);
                    end;
                  end;
                end;
              LLinePos := LPBookmarkText; { Go back where we were }
            end
            else
              LLinePos := LPBookmarkText; { Region close not found, return pointer back }
          end
          else
            LLinePos := LPBookmarkText; { Region close not found, return pointer back }
        end;

        Inc(LIndexDecrease);
      until Assigned(LCodeFoldingRange) and ((LCodeFoldingRange.RegionItem.BreakIfNotFoundBeforeNextRegion = '') or
        (LOpenTokenFoldRangeList.Count - LIndexDecrease < 0));
    end;
  end;

  function RegionItemsOpen: Boolean;
  var
    LArrayIndex: Integer;
    LIndex: Integer;
    LLineTempPos: PChar;
    LRange: TBCEditorCodeFoldingRanges.TRange;
    LRegionItem: TBCEditorCodeFoldingRegionItem;
    LSkipIfFoundAfterOpenToken: Boolean;
    LTokenEndPos: PChar;
    LTokenFollowEndPos: PChar;
    LTokenFollowPos: PChar;
    LTokenFollowText: string;
    LTokenPos: PChar;
    LTokenText: string;
  begin
    Result := False;

    if LOpenTokenSkipFoldRangeList.Count <> 0 then
      Exit;
    if CharInSet(UpCase(LLinePos^), FHighlighter.FoldOpenKeyChars) then
    begin
      LRange := nil;
      if LOpenTokenFoldRangeList.Count > 0 then
        LRange := LOpenTokenFoldRangeList.Last;
      if Assigned(LRange) and LRange.RegionItem.NoSubs then
        Exit;

      for LIndex := 0 to LCurrentCodeFoldingRegion.Count - 1 do
      begin
        LRegionItem := LCurrentCodeFoldingRegion[LIndex];
        if (LRegionItem.OpenTokenBeginningOfLine and LBeginningOfLine) or (not LRegionItem.OpenTokenBeginningOfLine) then
        begin
          { Check if extra token found }
          if Assigned(LRange) then
          begin
            if LRange.RegionItem.BreakIfNotFoundBeforeNextRegion <> '' then
              if (LLinePos^ = LRange.RegionItem.BreakIfNotFoundBeforeNextRegion[1]) then { If first character match }
              begin
                LTokenText := LRange.RegionItem.BreakIfNotFoundBeforeNextRegion;
                if (LTokenText <> '') then
                begin
                  LTokenPos := @LTokenText[1];
                  LTokenEndPos := @LTokenText[Length(LTokenText)];
                  LPBookmarkText := LLinePos;
                  { Check if open keyword found }
                  while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
                    and ((UpCase(LLinePos^) = LTokenPos^)
                      or CharInSet(LLinePos^, [BCEDITOR_NONE_CHAR, BCEDITOR_SPACE_CHAR, BCEDITOR_TAB_CHAR]))) do
                  begin
                    if (CharInSet(LTokenPos^, [BCEDITOR_NONE_CHAR, BCEDITOR_SPACE_CHAR, BCEDITOR_TAB_CHAR])
                      or not CharInSet(LLinePos^, [BCEDITOR_NONE_CHAR, BCEDITOR_SPACE_CHAR, BCEDITOR_TAB_CHAR])) then
                      Inc(LTokenPos);
                    Inc(LLinePos);
                  end;
                  if (LTokenPos > LTokenEndPos) then
                  begin
                    LRange.IsExtraTokenFound := True;
                    Continue;
                  end
                  else
                    LLinePos := LPBookmarkText; { Region not found, return pointer back }
                end;
              end;
          end;
          { First word after newline }
          if (UpCase(LLinePos^) = LRegionItem.OpenToken[1]) then { If first character match }
          begin
            LTokenText := LRegionItem.OpenToken;
            if (LTokenText <> '') then
            begin
              LTokenPos := @LTokenText[1];
              LTokenEndPos := @LTokenText[Length(LTokenText)];
              LPBookmarkText := LLinePos;
              { Check if open keyword found }
              while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
                and (UpCase(LLinePos^) = LTokenPos^)) do
              begin
                Inc(LLinePos);
                Inc(LTokenPos);
              end;

              if ((LRegionItem.OpenTokenCanBeFollowedBy <> '')
                and (UpCase(LLinePos^) = LRegionItem.OpenTokenCanBeFollowedBy[1])) then
              begin
                LLineTempPos := LLinePos;
                LTokenFollowText := LRegionItem.OpenTokenCanBeFollowedBy;
                LTokenFollowPos := @LTokenFollowText[1];
                LTokenFollowEndPos := @LTokenFollowText[Length(LTokenFollowText)];
                while (LLineTempPos <= LLineEndPos) and (LTokenFollowPos <= LTokenFollowEndPos)
                  and (UpCase(LLineTempPos^) = LTokenFollowPos^) do
                begin
                  Inc(LLineTempPos);
                  Inc(LTokenFollowPos);
                end;
                if (LTokenFollowPos > LTokenFollowEndPos) then
                  LLinePos := LLineTempPos;
              end;

              if (LTokenPos > LTokenEndPos) then
              begin
                if ((not LRegionItem.BreakCharFollows or LRegionItem.BreakCharFollows and IsWholeWord(LPBookmarkText - 1, LLinePos))
                  and not EscapeChar(LPBookmarkText - 1)) then { Not interested in partial hits }
                begin
                  { Check if special rule found }
                  LSkipIfFoundAfterOpenToken := False;
                  if (LRegionItem.SkipIfFoundAfterOpenTokenArrayCount > 0) then
                    while (LLinePos <= LLineEndPos) do
                    begin
                      for LArrayIndex := 0 to LRegionItem.SkipIfFoundAfterOpenTokenArrayCount - 1 do
                      begin
                        LTokenText := LRegionItem.SkipIfFoundAfterOpenTokenArray[LArrayIndex];
                        LTokenPos := @LTokenText[1];
                        LTokenEndPos := @LTokenText[Length(LTokenText)];
                        LPBookmarkText2 := LLinePos;
                        if (UpCase(LLinePos^) = LTokenPos^) then { If first character match }
                        begin
                          while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
                            and (UpCase(LLinePos^) = LTokenPos^)) do
                          begin
                            Inc(LLinePos);
                            Inc(LTokenPos);
                          end;
                          if (LTokenPos > LTokenEndPos) then
                          begin
                            LSkipIfFoundAfterOpenToken := True;
                            Break; { for }
                          end
                          else
                            LLinePos := LPBookmarkText2; { Region not found, return pointer back }
                        end;
                      end;
                      if LSkipIfFoundAfterOpenToken then
                        Break; { while }
                      Inc(LLinePos);
                    end;
                  if LSkipIfFoundAfterOpenToken then
                  begin
                    LLinePos := LPBookmarkText; { Skip found, return pointer back }
                    Continue;
                  end;

                  if Assigned(LRange) and (LRange.RegionItem.BreakIfNotFoundBeforeNextRegion <> '')
                    and not LRange.IsExtraTokenFound then
                  begin
                    LOpenTokenFoldRangeList.Remove(LRange);
                    Dec(LFoldCount);
                  end;

                  if LOpenTokenFoldRangeList.Count > 0 then
                    LFoldRanges := TBCEditorCodeFoldingRanges.TRange(LOpenTokenFoldRangeList.Last).SubCodeFoldingRanges
                  else
                    LFoldRanges := FAllCodeFoldingRanges;

                  LRange := LFoldRanges.Add(FAllCodeFoldingRanges, LLine, GetLineIndentLevel(LLine),
                    LFoldCount, LRegionItem, LLine);
                  { Open keyword found }
                  LOpenTokenFoldRangeList.Add(LRange);
                  Inc(LFoldCount);
                  Dec(LLinePos); { The end of the while loop will increase }
                  Result := LRegionItem.OpenTokenBreaksLine;
                  Break;
                end
                else
                  LLinePos := LPBookmarkText; { Region not found, return pointer back }
              end
              else
                LLinePos := LPBookmarkText; { Region not found, return pointer back }
            end;
          end;
        end;
      end;
    end;
  end;

  function MultiHighlighterOpen: Boolean;
  var
    LChar: Char;
    LCodeFoldingRegion: TBCEditorCodeFoldingRegion;
    LIndex: Integer;
    LTokenEndPos: PChar;
    LTokenPos: PChar;
    LTokenText: string;
  begin
    Result := False;
    if LOpenTokenSkipFoldRangeList.Count <> 0 then
      Exit;
    LChar := UpCase(LLinePos^);
    LPBookmarkText := LLinePos;
    for LIndex := 1 to Highlighter.CodeFoldingRangeCount - 1 do { First (0) is the default range }
    begin
      LCodeFoldingRegion := Highlighter.CodeFoldingRegions[LIndex];

      if (LChar = LCodeFoldingRegion.OpenToken[1]) then { If first character match }
      begin
        LTokenText := LCodeFoldingRegion.OpenToken;
        if (LTokenText <> '') then
        begin
          LTokenPos := @LTokenText[1];
          LTokenEndPos := @LTokenText[Length(LTokenText)];
          { Check if open keyword found }
          while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
            and (UpCase(LLinePos^) = LTokenPos^)) do
          begin
            Inc(LLinePos);
            Inc(LTokenPos);
          end;
          LLinePos := LPBookmarkText; { Return pointer always back }
          if (LTokenPos > LTokenEndPos) then
          begin
            LCodeFoldingRangeIndexList.Add(Pointer(LIndex));
            LCurrentCodeFoldingRegion := Highlighter.CodeFoldingRegions[LIndex];
            Exit(True)
          end;
        end;
      end;
    end;
  end;

  procedure MultiHighlighterClose;
  var
    LChar: Char;
    LCodeFoldingRegion: TBCEditorCodeFoldingRegion;
    LIndex: Integer;
    LTokenEndPos: PChar;
    LTokenPos: PChar;
    LTokenText: string;
  begin
    if (LOpenTokenSkipFoldRangeList.Count = 0) then
    begin
      LChar := UpCase(LLinePos^);
      LPBookmarkText := LLinePos;
      for LIndex := 1 to Highlighter.CodeFoldingRangeCount - 1 do { First (0) is the default range }
      begin
        LCodeFoldingRegion := Highlighter.CodeFoldingRegions[LIndex];

        if (LChar = LCodeFoldingRegion.CloseToken[1]) then { If first character match }
        begin
          LTokenText := LCodeFoldingRegion.CloseToken;
          if (LTokenText <> '') then
          begin
            LTokenPos := @LTokenText[1];
            LTokenEndPos := @LTokenText[Length(LTokenText)];
            { Check if close keyword found }
            while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
              and (UpCase(LLinePos^) = LTokenEndPos^)) do
            begin
              Inc(LLinePos);
              Inc(LTokenPos);
            end;
            LLinePos := LPBookmarkText; { Return pointer always back }
            if (LTokenPos > LTokenEndPos) then
            begin
              if LCodeFoldingRangeIndexList.Count > 0 then
                LCodeFoldingRangeIndexList.Delete(LCodeFoldingRangeIndexList.Count - 1);
              if LCodeFoldingRangeIndexList.Count > 0 then
                LCurrentCodeFoldingRegion := Highlighter.CodeFoldingRegions[Integer(LCodeFoldingRangeIndexList.Last)]
              else
                LCurrentCodeFoldingRegion := Highlighter.CodeFoldingRegions[DEFAULT_CODE_FOLDING_RANGE_INDEX];
              Exit;
            end
          end;
        end;
      end;
    end;
  end;

  function TagFolds: Boolean;
  var
    LCodeFoldingRegion: TBCEditorCodeFoldingRegion;
    LIndex: Integer;
  begin
    Result := False;
    for LIndex := 0 to Highlighter.CodeFoldingRangeCount - 1 do
    begin
      LCodeFoldingRegion := Highlighter.CodeFoldingRegions[LIndex];
      if LCodeFoldingRegion.FoldTags then
        Exit(True);
    end;
  end;

  procedure AddTagFolds;
  var
    LAdded: Boolean;
    LCloseToken: string;
    LOpenToken: string;
    LText: string;
    LTextBeginPos: PChar;
    LTextEndPos: PChar;
    LTextPos: PChar;
    LRegionItem: TBCEditorCodeFoldingRegionItem;
    LTokenAttributes: string;
    LTokenAttributesBeginPos: PChar;
    LTokenName: string;
    LRegion: TBCEditorCodeFoldingRegion;
  begin
    LText := FLines.Text;
    LTextBeginPos := @LText[1];
    LTextEndPos := @LText[Length(LText)];
    LTextPos := LTextBeginPos;
    LAdded := False;
    while (LTextPos <= LTextEndPos) do
    begin
      if (LTextPos^ = '<') then
      begin
        Inc(LTextPos);
        if not CharInSet(LTextPos^, ['?', '!', '/']) then
        begin
          LTokenName := '';
          while ((LTextPos <= LTextEndPos) and not CharInSet(LTextPos^, [' ', '>'])) do
          begin
            LTokenName := LTokenName + UpCase(LTextPos^);
            Inc(LTextPos);
          end;
          if (LTextPos^ <> ' ') then
            LTokenAttributes := ''
          else
          begin
            LTokenAttributesBeginPos := LTextPos;
            while ((LTextPos <= LTextEndPos) and not CharInSet(LTextPos^, ['/', '>'])) do
            begin
              Inc(LTextPos);
              if (CharInSet(LTextPos^, ['"', ''''])) then
              begin
                Inc(LTextPos);
                while ((LTextPos <= LTextEndPos) and not CharInSet(LTextPos^, ['"', ''''])) do
                  Inc(LTextPos);
              end;
            end;
            LTokenAttributes := UpperCase(Copy(LText, 1 + LTokenAttributesBeginPos - LTextBeginPos, LTextPos - LTokenAttributesBeginPos));
          end;

          LOpenToken := '<' + LTokenName + LTokenAttributes + LTextPos^;
          LCloseToken := '</' + LTokenName + '>';

          if (LTextPos^ = '>') and (LTextPos^ <> '/') then
          begin
            LRegion := FHighlighter.CodeFoldingRegions[0];
            if not LRegion.Contains(LOpenToken, LCloseToken) then { First (0) is the default range }
            begin
              LRegionItem := LRegion.Add(LOpenToken, LCloseToken);
              LRegionItem.BreakCharFollows := False;
              LAdded := True;
            end;
          end;
        end;
      end;
      Inc(LTextPos);
    end;
    if (LAdded) then
    begin
      FHighlighter.AddKeyChar(ctFoldOpen, '<');
      FHighlighter.AddKeyChar(ctFoldClose, '<');
    end;
  end;

var
  LRange: TBCEditorCodeFoldingRanges.TRange;
  LRow: Integer;
  LPreviousLine: Integer;
begin
  LFoldCount := 0;
  LOpenTokenSkipFoldRangeList := TList.Create;
  LOpenTokenFoldRangeList := TList.Create;
  LCodeFoldingRangeIndexList := TList.Create;
  try
    if TagFolds then
      AddTagFolds;

    { Go through the text line by line, character by character }
    LPreviousLine := -1;

    LCodeFoldingRangeIndexList.Add(Pointer(DEFAULT_CODE_FOLDING_RANGE_INDEX));

    if Highlighter.CodeFoldingRangeCount > 0 then
      LCurrentCodeFoldingRegion := Highlighter.CodeFoldingRegions[DEFAULT_CODE_FOLDING_RANGE_INDEX];

    for LRow := 0 to FRows.Count - 1 do
    begin
      LLine := FRows.Items[LRow].Line;
      LRange := TBCEditorCodeFoldingRanges.TRange(FLines.Items[LLine].CodeFolding.BeginRange);
      if Assigned(LRange) and LRange.Collapsed then
      begin
        LPreviousLine := LLine;
        Continue;
      end;

      if ((LPreviousLine <> LLine) and (FLines.Items[LLine].Text <> '')) then
      begin
        LLinePos := @FLines.Items[LLine].Text[1];
        LLineEndPos := @FLines.Items[LLine].Text[Length(FLines.Items[LLine].Text)];
        LBeginningOfLine := True;
        while (LLinePos <= LLineEndPos) do
          if (not SkipEmptySpace()) then
          begin
            if Highlighter.MultiHighlighter then
              if not MultiHighlighterOpen then
                MultiHighlighterClose;

            if SkipRegionsClose then
              Continue; { while LTextPos <= LTextEndPos do }
            if SkipRegionsOpen then
              Break; { Line comment breaks }

            if SkipEmptySpace then
              Break;

            if LOpenTokenSkipFoldRangeList.Count = 0 then
            begin
              RegionItemsClose;
              if RegionItemsOpen then
                Break; { OpenTokenBreaksLine region item option breaks }
            end;

            if (LLinePos <= LLineEndPos) then
              Inc(LLinePos);

            { Skip rest of the word }
            while ((LLinePos <= LLineEndPos)
              and (LLinePos^.IsLower or LLinePos^.IsUpper or LLinePos^.IsNumber)) do
              Inc(LLinePos);

            LBeginningOfLine := False; { Not in the beginning of the line anymore }
          end;
      end;
      LPreviousLine := LLine;
    end;
    { Check the last not empty line }
    LLine := FLines.Count - 1;
    while (LLine >= 0) and (Trim(FLines.Items[LLine].Text) = '') do
      Dec(LLine);
    if ((LLine >= 0) and (FLines.Items[LLine].Text <> '')) then
    begin
      LLinePos := @FLines.Items[LLine].Text[1];
      LLineEndPos := @FLines.Items[LLine].Text[Length(FLines.Items[LLine].Text)];
      while LOpenTokenFoldRangeList.Count > 0 do
      begin
        LLastFoldRange := LOpenTokenFoldRangeList.Last;
        if Assigned(LLastFoldRange) then
        begin
          Inc(LLine);
          LLine := Min(LLine, FLines.Count - 1);
          if LLastFoldRange.RegionItem.OpenIsClose then
            LLastFoldRange.EndLine := LLine;
          LOpenTokenFoldRangeList.Remove(LLastFoldRange);
          Dec(LFoldCount);
          RegionItemsClose;
        end;
      end;
    end;
  finally
    LCodeFoldingRangeIndexList.Free;
    LOpenTokenSkipFoldRangeList.Free;
    LOpenTokenFoldRangeList.Free;
  end;
end;

procedure TCustomBCEditor.ScrollTo(AValue: TPoint);
begin
  ScrollTo(AValue, True);
end;

procedure TCustomBCEditor.ScrollTo(AValue: TPoint; const AAlignToRow: Boolean);
var
  LValue: TPoint;
begin
  LValue := AValue;
  if (AAlignToRow and (FLineHeight > 0)) then
    Dec(LValue.Y, LValue.Y mod FLineHeight);

  if (LValue <> FTextPos) then
    ProcessCommand(ecScrollTo, TBCEditorCommandDataScrollTo.Create(LValue));
end;

procedure TCustomBCEditor.ScrollTo(AX, AY: Integer);
begin
  ScrollTo(Point(AX, AY), True);
end;

procedure TCustomBCEditor.ScrollToPosition(const APosition: TBCEditorLinesPosition);
var
  LTextPos: TPoint;
  LNewTextPos: TPoint;
begin
  if ((FRows.Count > 0)
    and (GetWindowLong(WindowHandle, GWL_STYLE) and (ES_AUTOVSCROLL or ES_AUTOHSCROLL) <> 0)) then
  begin
    FBuildRowsCriticalSection.Enter();
    try
      if (APosition.Line <= FLastLineInBuiltRows) then
        LTextPos := RowsToText(LinesToRows(APosition))
      else
      begin
        FRowsWanted.What := rwScrollToPosition;
        FRowsWanted.Position := APosition;
        FRowsWanted.CenterCaret := esCenterCaret in FState;
        UpdateCursor();
      end;
    finally
      FBuildRowsCriticalSection.Leave();
    end;

    LNewTextPos := FTextPos;

    if (GetWindowLong(WindowHandle, GWL_STYLE) and ES_AUTOHSCROLL <> 0) then
    begin
      if (LTextPos.X < LNewTextPos.X) then
        if (not (esCenterCaret in FState)) then
          LNewTextPos.X := LTextPos.X
        else if (LTextPos.X < FMetrics.TextRect.Width * 3 div 4) then
          LNewTextPos.X := 0
        else
          LNewTextPos.X := LTextPos.X - FMetrics.TextRect.Width * 3 div 4;
      if (LTextPos.X > LNewTextPos.X + FMetrics.TextRect.Width - FCaretWidth) then
        if (not (esCenterCaret in FState)) then
          LNewTextPos.X := LTextPos.X + FCaretWidth - FMetrics.TextRect.Width
        else
          LNewTextPos.X := LTextPos.X - FMetrics.TextRect.Width * 3 div 4;
    end;

    if (GetWindowLong(WindowHandle, GWL_STYLE) and ES_AUTOVSCROLL <> 0) then
    begin
      if (LTextPos.Y < LNewTextPos.Y) then
        if (not (esCenterCaret in FState)) then
          LNewTextPos.Y := LTextPos.Y
        else
          LNewTextPos.Y := Max(0, FRows.CaretPosition.Row - FUsableRows div 2) * FLineHeight;
      if (LTextPos.Y > LNewTextPos.Y + (FUsableRows - 1) * FLineHeight) then
        if (not (esCenterCaret in FState)) then
          LNewTextPos.Y := LTextPos.Y - (FUsableRows - 1) * FLineHeight
        else
          LNewTextPos.Y := Max(0, FRows.CaretPosition.Row - FUsableRows div 2) * FLineHeight;
    end;

    SetTextPos(LNewTextPos);
  end;
end;

procedure TCustomBCEditor.SelectAll();
begin
  ProcessCommand(ecSelectAll);
end;

function TCustomBCEditor.SelectedText(): string;
begin
  Result := SelText;
end;

function TCustomBCEditor.SelectionAvailable: Boolean;
begin
  Result := SelLength <> 0;
end;

procedure TCustomBCEditor.SetBookmark(const AIndex: Integer; const ALinesPosition: TBCEditorLinesPosition);
var
  LBookmark: TBCEditorLines.TMark;
  LIndex: Integer;
begin
  if (ALinesPosition.Line >= 0) and (ALinesPosition.Line <= Max(0, FLines.Count - 1)) then
  begin
    LIndex := FLines.Bookmarks.IndexOfIndex(AIndex);
    if (LIndex >= 0) then
      FLines.Bookmarks.Delete(LIndex);

    LBookmark := TBCEditorLines.TMark.Create(FLines.Bookmarks);
    LBookmark.Pos := ALinesPosition;
    LBookmark.ImageIndex := Min(AIndex, BCEDITOR_BOOKMARKS - 1);
    LBookmark.Index := AIndex;
    LBookmark.Visible := True;
    FLines.Bookmarks.Add(LBookmark);
  end;
end;

procedure TCustomBCEditor.SetBorderStyle(const AValue: TBorderStyle);
begin
  if (AValue <> FBorderStyle) then
  begin
    FBorderStyle := AValue;
    RecreateWnd;
  end;
end;

procedure TCustomBCEditor.SetCaretPos(AValue: TPoint);
begin
  ProcessCommand(ecPosition, TBCEditorCommandDataPosition.Create(AValue));
end;

procedure TCustomBCEditor.SetCaretPosition(const APosition: TBCEditorLinesPosition; const ASelect: Boolean);
begin
  if (not ASelect) then
    FLines.CaretPosition := APosition
  else
    SetSelArea(LinesArea(FLines.SelBeginPosition, APosition), APosition < FLines.SelBeginPosition);
end;

procedure TCustomBCEditor.SetColors(AValue: TBCEditorColors);
begin
  FColors.Assign(AValue);
end;

procedure TCustomBCEditor.SetCursor(AValue: TCursor);
begin
  if ((not ReadOnly and not FLines.CanModify)
    or (FRowsWanted.What <> rwNothing)) then
    inherited Cursor := crHourGlass
  else if (esScrolling in FState) then
    inherited Cursor := crSizeAll
  else
    inherited Cursor := AValue;

  Windows.SetCursor(Screen.Cursors[inherited Cursor]);
end;

procedure TCustomBCEditor.SetFocus();
begin
  // Todo: Implement EIMES_CANCELCOMPSTRINGFOCUS and EIMES_COMPLETECOMPSTRKILLFOCUS

  inherited;
end;

procedure TCustomBCEditor.SetHideScrollBars(AValue: Boolean);
begin
  if (AValue <> FHideScrollBars) then
  begin
    FHideScrollBars := AValue;
    InvalidateScrollBars();
  end;
end;

procedure TCustomBCEditor.SetHideSelection(AValue: Boolean);
begin
  if (AValue <> FHideSelection) then
  begin
    FHideSelection := HideSelection;
    if (HandleAllocated) then
      if (not AValue) then
        SetWindowLong(WindowHandle, GWL_STYLE, GetWindowLong(WindowHandle, GWL_STYLE) or ES_NOHIDESEL)
      else
        SetWindowLong(WindowHandle, GWL_STYLE, GetWindowLong(WindowHandle, GWL_STYLE) and not ES_NOHIDESEL);
  end;
end;

procedure TCustomBCEditor.SetLeftMargin(const AValue: TBCEditorLeftMargin);
begin
  FLeftMargin.Assign(AValue);
end;

procedure TCustomBCEditor.SetLines(const AValue: TStrings);
begin
  FLines.Assign(AValue);
end;

procedure TCustomBCEditor.SetLinesBeginRanges(const AValue: Integer);
var
  LLine: Integer;
  LRange: TBCEditorHighlighter.TRange;
  LToken: TBCEditorHighlighter.TTokenFind;
begin
  Assert((0 <= AValue) and (AValue < FLines.Count));

  LLine := AValue;
  while (LLine < FLines.Count - 1) do
  begin
    if (not FHighlighter.FindFirstToken(FLines.Items[LLine].BeginRange,
      PChar(FLines.Items[LLine].Text), Length(FLines.Items[LLine].Text), 0, LToken)) then
      LRange := FLines.Items[LLine].BeginRange
    else
    begin
      repeat
        LRange := LToken.Range;
      until (not FHighlighter.FindNextToken(LToken));
      FHighlighter.FindClose(LToken);
    end;

    if (LRange = FLines.Items[LLine + 1].BeginRange) then
      exit;

    FLines.SetBeginRange(LLine + 1, LRange);
    Inc(LLine);
  end;
end;

procedure TCustomBCEditor.SetTextPos(const AValue: TPoint);
var
  LTextPos: TPoint;
begin
  if (Assigned(FHintWindow)) then
    FreeAndNil(FHintWindow);

  LTextPos := AValue;
  if (not (eoBeyondEndOfLine in FOptions)) then
    if (eoShowSpecialChars in FOptions) then
      LTextPos.X := Min(LTextPos.X, FRows.MaxWidth + FLineBreakSignWidth + FCaretWidth - FMetrics.TextRect.Width)
    else
      LTextPos.X := Min(LTextPos.X, FRows.MaxWidth + FCaretWidth - FMetrics.TextRect.Width);
  LTextPos.X := Max(0, LTextPos.X);
  if (not (eoBeyondEndOfFile in FOptions)) then
    LTextPos.Y := Min(LTextPos.Y, (FRows.Count - FUsableRows) * FLineHeight);
  LTextPos.Y := Max(0, LTextPos.Y);

  if (LTextPos <> FTextPos) then
  begin
    if (LTextPos.X <> FTextPos.X) then
      NotifyParent(EN_HSCROLL);
    if (LTextPos.Y <> FTextPos.Y) then
      NotifyParent(EN_VSCROLL);

    FTextPos := LTextPos;
    FTopRow := FTextPos.Y div FLineHeight;

    if (not (esPainting in FState)) then
      InvalidateText(LTextPos.Y <> FTextPos.Y)
    else
      InvalidateCaret();
    InvalidateScrollBars();
  end;
end;

procedure TCustomBCEditor.SetTextPos(AX, AY: Integer);
begin
  SetTextPos(Point(AX, AY));
end;

procedure TCustomBCEditor.SetInsertPos(AValue: TPoint);
var
  LClient: TPoint;
  LGraphics: TGPGraphics;
begin
  if (AValue <> FInsertPos) then
  begin
    if (HandleAllocated and Assigned(FInsertPosCache)) then
    begin
      if (not InvalidPoint(FInsertPos)) then
      begin
        LClient := RowsToClient(LinesToRows(FInsertPos), True);
        if (FInsertPos.X >= 0) then
          BitBlt(Canvas.Handle, LClient.X - GLineWidth, LClient.Y, 3 * GLineWidth, FLineHeight,
            FInsertPosCache.Canvas.Handle, 0, 0,
            SRCCOPY);
      end;
      FInsertPosCache.Free();
      FInsertPosCache := nil;
    end;

    if (AValue.Y < 0) then
      FInsertPos := InvalidPos
    else
    begin
      AValue.X := Max(AValue.X, 0);
      AValue.Y := Min(AValue.Y, Max(0, FLines.Count - 1));
      if (AValue.Y < FLines.Count) then
        AValue.X := Min(AValue.X, FRows.Items[AValue.Y].Length)
      else
        AValue.X := 0;

      FInsertPos := AValue;

      if (HandleAllocated
        and (not InvalidPoint(FInsertPos))
        and ((FTopRow <= LinesToRows(FInsertPos).Row) and (LinesToRows(FInsertPos).Row <= FTopRow + FVisibleRows))) then
      begin
        LClient := RowsToClient(LinesToRows(FInsertPos), True);
        FInsertPosCache := TBitmap.Create();
        FInsertPosCache.Handle := CreateCompatibleBitmap(Canvas.Handle, 3 * GLineWidth, FLineHeight);

        BitBlt(FInsertPosCache.Canvas.Handle, 0, 0, 3 * GLineWidth, FLineHeight,
          Canvas.Handle, LClient.X - GLineWidth, LClient.Y,
          SRCCOPY);
        LGraphics := TGPGraphics.Create(Canvas.Handle);
        LGraphics.DrawCachedBitmap(FInsertPosBitmap, LClient.X - GLineWidth, LClient.Y);
        LGraphics.Free();
      end;
    end;
  end;
end;

procedure TCustomBCEditor.SetLineColor(const ALine: Integer; const AForegroundColor, ABackgroundColor: TColor);
begin
  if ((0 <= ALine) and (ALine < FLines.Count)
    and ((AForegroundColor <> FLines.Items[ALine].Foreground) or (ABackgroundColor <> FLines.Items[ALine].Background))) then
  begin
    FLines.SetForeground(ALine, AForegroundColor);
    FLines.SetBackground(ALine, ABackgroundColor);
    InvalidateText(ALine);
  end;
end;

procedure TCustomBCEditor.SetMark(const AIndex: Integer; const ALinesPosition: TBCEditorLinesPosition;
  const AImageIndex: Integer);
var
  LIndex: Integer;
  LMark: TBCEditorLines.TMark;
begin
  if (ALinesPosition.Line >= 0) and (ALinesPosition.Line <= Max(0, FLines.Count - 1)) then
  begin
    LIndex := FLines.Marks.IndexOfIndex(AIndex);
    if (LIndex >= 0) then
      FLines.Marks.Delete(LIndex);

    LMark := TBCEditorLines.TMark.Create(FLines.Marks);
    with LMark do
    begin
      Pos := ALinesPosition;
      ImageIndex := AImageIndex;
      Index := AIndex;
      Visible := True;
    end;
    FLines.Marks.Add(LMark);
  end;
end;

procedure TCustomBCEditor.SetModified(const AValue: Boolean);
begin
  FLines.Modified := AValue;
end;

procedure TCustomBCEditor.SetMouseCapture(const AValue: TMouseCapture);
begin
  if (AValue <> FMouseCapture) then
  begin
    FMouseCapture := AValue;

    inherited MouseCapture := FMouseCapture <> mcNone;
  end;
end;

procedure TCustomBCEditor.SetOptions(const AValue: TBCEditorOptions);
begin
  if (AValue <> FOptions) then
  begin
    FOptions := AValue;

    if (eoTrimTrailingLines in FOptions) then
      FLines.Options := FLines.Options + [loTrimTrailingLines]
    else
      FLines.Options := FLines.Options - [loTrimTrailingLines];
    if (eoTrimTrailingSpaces in FOptions) then
      FLines.Options := FLines.Options + [loTrimTrailingSpaces]
    else
      FLines.Options := FLines.Options - [loTrimTrailingSpaces];
    if (eoBeyondEndOfLine in FOptions) then
      FLines.Options := FLines.Options + [loBeyondEOL]
    else
      FLines.Options := FLines.Options - [loBeyondEOL];
    if (eoBeyondEndOfFile in FOptions) then
      FLines.Options := FLines.Options + [loBeyondEOF]
    else
      FLines.Options := FLines.Options - [loBeyondEOF];
    if (eoDropFiles in FOptions) then
      SetWindowLong(WindowHandle, GWL_EXSTYLE, GetWindowLong(WindowHandle, GWL_EXSTYLE) or WS_EX_ACCEPTFILES)
    else
      SetWindowLong(WindowHandle, GWL_EXSTYLE, GetWindowLong(WindowHandle, GWL_EXSTYLE) and not WS_EX_ACCEPTFILES);
  end;

  InvalidateClient();
end;

procedure TCustomBCEditor.SetParent(AParent: TWinControl);
begin
  inherited;

  if (not Assigned(Parent)) then
  begin
    FFormWnd := 0;
    FParentWnd := 0;
  end
  else
  begin
    FFormWnd := GetParentForm(Self).Handle;
    FParentWnd := Parent.Handle;
  end;
end;

procedure TCustomBCEditor.SetReadOnly(const AValue: Boolean);
begin
  if (AValue <> FReadOnly) then
  begin
    FReadOnly := AValue;
    if (not FReadOnly) then
      FLines.Options := FLines.Options - [loReadOnly]
    else
      FLines.Options := FLines.Options + [loReadOnly];
    if (HandleAllocated) then
      if (not FReadOnly) then
        SetWindowLong(WindowHandle, GWL_STYLE, GetWindowLong(WindowHandle, GWL_STYLE) and not ES_READONLY)
      else
        SetWindowLong(WindowHandle, GWL_STYLE, GetWindowLong(WindowHandle, GWL_STYLE) or ES_READONLY);
  end;
end;

procedure TCustomBCEditor.SetScrollBars(const AValue: UITypes.TScrollStyle);
begin
  if (AValue <> FScrollBars) then
  begin
    FScrollBars := AValue;
    InvalidateScrollBars();
  end;
end;

procedure TCustomBCEditor.SetSelArea(const ASelArea: TBCEditorLinesArea;
  const ACaretToBeginPosition: Boolean = False);
begin
  if (ACaretToBeginPosition) then
    FLines.SelArea := LinesArea(Max(ASelArea.BeginPosition, ASelArea.EndPosition), Min(ASelArea.BeginPosition, ASelArea.EndPosition))
  else
    FLines.SelArea := LinesArea(Min(ASelArea.BeginPosition, ASelArea.EndPosition), Max(ASelArea.BeginPosition, ASelArea.EndPosition))
end;

procedure TCustomBCEditor.SetSelectedWord();
begin
  SetWordBlock(FLines.CaretPosition);
end;

procedure TCustomBCEditor.SetSelLength(AValue: Integer);
begin
  if (AValue < 0) then
    ProcessCommand(ecSel,
      TBCEditorCommandDataSelection.Create(LinesArea(FLines.PositionOf(AValue, FLines.SelArea.BeginPosition), FLines.SelArea.BeginPosition)))
  else
    ProcessCommand(ecSel,
      TBCEditorCommandDataSelection.Create(LinesArea(FLines.SelArea.BeginPosition, FLines.PositionOf(AValue, FLines.SelArea.BeginPosition))));
end;

procedure TCustomBCEditor.SetSelStart(AValue: Integer);
var
  LCaretPosition: TBCEditorLinesPosition;
begin
  LCaretPosition := FLines.PositionOf(AValue);
  ProcessCommand(ecPosition, TBCEditorCommandDataPosition.Create(LCaretPosition));
end;

procedure TCustomBCEditor.SetSelText(const AValue: string);
begin
  ProcessCommand(ecText, TBCEditorCommandDataText.Create(AValue, True, True));
end;

procedure TCustomBCEditor.SetSelectionOptions(AValue: TBCEditorSelectionOptions);
begin
  if (AValue <> FSelectionOptions) then
  begin
    FSelectionOptions := AValue;
    if (not FLines.SelArea.IsEmpty()) then
      InvalidateText();
  end;
end;

procedure TCustomBCEditor.SetSyncEditOptions(AValue: TBCEditorSyncEditOptions);
begin
  if (AValue <> FSyncEditOptions) then
  begin
    FSyncEditOptions := AValue;

    if (seoCaseSensitive in FSyncEditOptions) then
      FLines.Options := FLines.Options + [loSyncEditCaseSensitive]
    else
      FLines.Options := FLines.Options - [loSyncEditCaseSensitive];

    if (FLines.SyncEdit) then
    begin
      FLines.SelArea := FLines.SyncEditArea;
      ProcessCommand(ecSyncEdit); // Deactivate
      ProcessCommand(ecSyncEdit); // Re-activate
    end;
  end;
end;

procedure TCustomBCEditor.SetTabs(const AValue: TBCEditorTabs);
begin
  FTabs.Assign(AValue);
end;

procedure TCustomBCEditor.SetText(const AValue: string);
begin
  FLines.Text := AValue;
end;

procedure TCustomBCEditor.SetTopRow(const AValue: Integer);
begin
  ScrollTo(FTextPos.X, AValue * FLineHeight);
end;

procedure TCustomBCEditor.SetUndoOption(const AOption: TBCEditorUndoOption; const AEnabled: Boolean);
begin
  case (AOption) of
    uoGroupUndo:
      if (AEnabled) then
        FLines.Options := FLines.Options + [loUndoGrouped]
      else
        FLines.Options := FLines.Options - [loUndoGrouped];
    uoUndoAfterLoad:
      if (AEnabled) then
        FLines.Options := FLines.Options + [loUndoAfterLoad]
      else
        FLines.Options := FLines.Options - [loUndoAfterLoad];
    uoUndoAfterSave:
      if (AEnabled) then
        FLines.Options := FLines.Options + [loUndoAfterSave]
      else
        FLines.Options := FLines.Options - [loUndoAfterSave];
  end;
end;

procedure TCustomBCEditor.SetUndoOptions(AOptions: TBCEditorUndoOptions);
var
  LLinesOptions: TBCEditorLines.TOptions;
begin
  LLinesOptions := FLines.Options;
  LLinesOptions := LLinesOptions - [loUndoGrouped, loUndoAfterLoad, loUndoAfterSave];
  if (uoGroupUndo in AOptions) then
    LLinesOptions := LLinesOptions + [loUndoGrouped];
  if (uoUndoAfterLoad in AOptions) then
    LLinesOptions := LLinesOptions + [loUndoAfterLoad];
  if (uoUndoAfterSave in AOptions) then
    LLinesOptions := LLinesOptions + [loUndoAfterSave];
  FLines.Options := LLinesOptions;
end;

procedure TCustomBCEditor.SetUpdateState(AUpdating: Boolean);
begin
  if (not AUpdating) then
  begin
    if ((FState * [esTextChanged] <> [])
      and not (csReading in ComponentState)) then
      Change();
    if (Assigned(FOnCaretChanged) and (FState * [esCaretChanged] <> [])) then
      FOnCaretChanged(Self, CaretPos);
    if ((FState * [esSelChanged] <> []) and Assigned(FOnSelChanged)) then
      FOnSelChanged(Self);

    if ((FState * [esCaretInvalid] <> [])
      and (FRows.Count > 0)
      and HandleAllocated
      and not GetUpdateRect(WindowHandle, nil, not (csOpaque in ControlStyle))) then
      UpdateCaret();

    FState := FState - [esTextChanged, esSelChanged, esCaretChanged];
  end;
end;

procedure TCustomBCEditor.SetWantReturns(const AValue: Boolean);
begin
  if (AValue <> FWantReturns) then
  begin
    FWantReturns := AValue;
    if (HandleAllocated) then
      if (not AValue) then
        SetWindowLong(WindowHandle, GWL_STYLE, GetWindowLong(WindowHandle, GWL_STYLE) and not ES_WANTRETURN)
      else
        SetWindowLong(WindowHandle, GWL_STYLE, GetWindowLong(WindowHandle, GWL_STYLE) or ES_WANTRETURN);
  end;
end;

procedure TCustomBCEditor.SetWordBlock(const ALinesPosition: TBCEditorLinesPosition);
var
  LArea: TBCEditorLinesArea;
  LLineTextLength: Integer;
begin
  if (ALinesPosition.Line < FLines.Count) then
  begin
    LLineTextLength := Length(FLines.Items[ALinesPosition.Line].Text);

    LArea.BeginPosition := LinesPosition(Min(ALinesPosition.Char, LLineTextLength), ALinesPosition.Line);
    while ((LArea.BeginPosition.Char > 0)
      and not IsWordBreakChar(FLines.Items[ALinesPosition.Line].Text[1 + LArea.BeginPosition.Char - 1])) do
      Dec(LArea.BeginPosition.Char);
    while ((LArea.BeginPosition.Char > 0)
      and not IsWordBreakChar(FLines.Items[ALinesPosition.Line].Text[1 + LArea.BeginPosition.Char - 1])) do
      Dec(LArea.BeginPosition.Char);
    if ((soDoubleClickRealNumbers in FSelectionOptions) and FLines.Items[ALinesPosition.Line].Text[1 + LArea.BeginPosition.Char].IsNumber) then
      while ((LArea.BeginPosition.Char > 0)
        and CharInSet(FLines.Items[ALinesPosition.Line].Text[1 + LArea.BeginPosition.Char - 1], BCEDITOR_REAL_NUMBER_CHARS)) do
        Dec(LArea.BeginPosition.Char);

    LArea.EndPosition := LArea.BeginPosition;
    while ((LArea.EndPosition.Char < LLineTextLength)
      and not IsWordBreakChar(FLines.Items[ALinesPosition.Line].Text[1 + LArea.EndPosition.Char])) do
      Inc(LArea.EndPosition.Char);
    if ((soDoubleClickRealNumbers in FSelectionOptions) and FLines.Items[ALinesPosition.Line].Text[1 + LArea.BeginPosition.Char].IsNumber) then
      while ((LArea.EndPosition.Char < LLineTextLength)
        and CharInSet(FLines.Items[ALinesPosition.Line].Text[1 + LArea.EndPosition.Char], BCEDITOR_REAL_NUMBER_CHARS)) do
        Inc(LArea.EndPosition.Char);

    SetSelArea(LArea);
  end;
end;

procedure TCustomBCEditor.SetWordWrap(const AValue: Boolean);
begin
  if (AValue <> FWordWrap) then
  begin
    FWordWrap := AValue;

    ScrollToPosition(FLines.CaretPosition);

    InvalidateClient();
  end;
end;

procedure TCustomBCEditor.Sort(const ASortOrder: TBCEditorSortOrder = soAsc; const ACaseSensitive: Boolean = False);
var
  LBeginLine: Integer;
  LEndLine: Integer;
  LLine: Integer;
  LSelectionBeginPosition: TBCEditorLinesPosition;
  LSelectionEndPosition: TBCEditorLinesPosition;
begin
  for LLine := 0 to FLines.Count - 1 do
  begin
    FLines.SetCodeFoldingBeginRange(LLine, nil);
    FLines.SetCodeFoldingEndRange(LLine, nil);
    FLines.SetCodeFoldingTreeLine(LLine, False);
  end;

  if (not FLines.SelArea.IsEmpty()) then
  begin
    LSelectionBeginPosition := FLines.SelArea.BeginPosition;
    LSelectionEndPosition := FLines.SelArea.EndPosition;

    LBeginLine := LSelectionBeginPosition.Line;
    LEndLine := LSelectionEndPosition.Line;
    if ((LSelectionEndPosition.Char = 0) and (LSelectionEndPosition.Line > LSelectionBeginPosition.Line)) then
      Dec(LEndLine);
  end
  else
  begin
    LBeginLine := 0;
    LEndLine := FLines.Count - 1;
  end;

  FLines.CaseSensitive := ACaseSensitive;
  FLines.SortOrder := ASortOrder;
  FLines.Sort(LBeginLine, LEndLine);

  InvalidateRows();
  InvalidateCodeFolding();
end;

function TCustomBCEditor.SplitTextIntoWords(AStringList: TStrings; const ACaseSensitive: Boolean): string;
var
  LSkipCloseKeyChars: TBCEditorAnsiCharSet;
  LSkipOpenKeyChars: TBCEditorAnsiCharSet;
  LSkipRegionItem: TBCEditorCodeFoldingSkipRegions.TItem;

  procedure AddKeyChars();
  var
    LIndex: Integer;
    LTokenEndPos: PChar;
    LTokenPos: PChar;
    LTokenText: string;
  begin
    LSkipOpenKeyChars := [];
    LSkipCloseKeyChars := [];

    for LIndex := 0 to FHighlighter.CompletionProposalSkipRegions.Count - 1 do
    begin
      LSkipRegionItem := FHighlighter.CompletionProposalSkipRegions[LIndex];

      LTokenText := LSkipRegionItem.OpenToken;
      if (LTokenText <> '') then
      begin
        LTokenPos := @LTokenText[1];
        LTokenEndPos := @LTokenText[Length(LTokenText)];
        while (LTokenPos <= LTokenEndPos) do
        begin
          LSkipOpenKeyChars := LSkipOpenKeyChars + [LTokenPos^];
          Inc(LTokenPos);
        end;

        LTokenText := LSkipRegionItem.CloseToken;
        if (LTokenText <> '') then
        begin
          LTokenPos := @LTokenText[1];
          LTokenEndPos := @LTokenText[Length(LTokenText)];
          while (LTokenPos <= LTokenEndPos) do
          begin
            LSkipCloseKeyChars := LSkipCloseKeyChars + [LTokenPos^];
            Inc(LTokenPos);
          end;
        end;
      end;
    end;
  end;

var
  LIndex: Integer;
  LLine: Integer;
  LLineEndPos: PChar;
  LLinePos: PChar;
  LOpenTokenSkipFoldRangeList: TList;
  LPBookmarkText: PChar;
  LStringList: TStringList;
  LTokenEndPos: PChar;
  LTokenPos: PChar;
  LTokenText: string;
  LWord: string;
  LWordList: string;
begin
  Result := '';
  AddKeyChars;
  AStringList.Clear;
  LOpenTokenSkipFoldRangeList := TList.Create;
  try
    for LLine := 0 to FLines.Count - 1 do
      if (FLines.Items[LLine].Text <> '') then
      begin
        { Add document words }
        LLinePos := @FLines.Items[LLine].Text[1];
        LLineEndPos := @FLines.Items[LLine].Text[Length(FLines.Items[LLine].Text)];
        LWord := '';
        while (LLinePos <= LLineEndPos) do
        begin
          { Skip regions - Close }
          if (LOpenTokenSkipFoldRangeList.Count > 0) and CharInSet(LLinePos^, LSkipCloseKeyChars) then
          begin
            LTokenText := TBCEditorCodeFoldingSkipRegions.TItem(LOpenTokenSkipFoldRangeList.Last).CloseToken;
            if (LTokenText <> '') then
            begin
              LTokenPos := @LTokenText[1];
              LTokenEndPos := @LTokenText[Length(LTokenText)];
              LPBookmarkText := LLinePos;
              { Check if the close keyword found }
              while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
                and (LLinePos^ = LTokenPos^)) do
              begin
                Inc(LLinePos);
                Inc(LTokenPos);
              end;
              if (LTokenPos > LTokenEndPos) then { If found, pop skip region from the list }
              begin
                LOpenTokenSkipFoldRangeList.Delete(LOpenTokenSkipFoldRangeList.Count - 1);
                Continue;
              end
              else
                LLinePos := LPBookmarkText;
                { Skip region close not found, return pointer back }
            end;
          end;

          { Skip regions - Open }
          if (CharInSet(LLinePos^, LSkipOpenKeyChars)) then
            for LIndex := 0 to FHighlighter.CompletionProposalSkipRegions.Count - 1 do
            begin
              LSkipRegionItem := FHighlighter.CompletionProposalSkipRegions[LIndex];
              LTokenText := LSkipRegionItem.OpenToken;
              if ((LTokenText <> '') and (LLinePos^ = LTokenText[1])) then { If the first character is a match }
              begin
                LTokenPos := @LTokenText[1];
                LTokenEndPos := @LTokenText[Length(LTokenText)];
                LPBookmarkText := LLinePos;
                { Check if the open keyword found }
                while ((LLinePos <= LLineEndPos) and (LTokenPos <= LTokenEndPos)
                  and (LLinePos^ = LTokenPos^)) do
                begin
                  Inc(LLinePos);
                  Inc(LTokenPos);
                end;
                if (LTokenPos > LTokenEndPos) then { If found, skip single line comment or push skip region into stack }
                begin
                  if LSkipRegionItem.RegionType = ritSingleLineComment then
                    { Single line comment skip until next line }
                    LLinePos := LLineEndPos
                  else
                    LOpenTokenSkipFoldRangeList.Add(LSkipRegionItem);
                  Dec(LLinePos); { The end of the while loop will increase }
                  Break;
                end
                else
                  LLinePos := LPBookmarkText;
                { Skip region open not found, return pointer back }
              end;
            end;

          if LOpenTokenSkipFoldRangeList.Count = 0 then
          begin
            if ((LWord = '') and (LLinePos^.IsLower or LLinePos^.IsUpper or (LLinePos^ = BCEDITOR_UNDERSCORE))
              or (LWord <> '') and (LLinePos^.IsLower or LLinePos^.IsUpper or LLinePos^.IsNumber or (LLinePos^ = BCEDITOR_UNDERSCORE))) then
              LWord := LWord + LLinePos^
            else
            begin
              if (LWord <> '') and (Length(LWord) > 1) then
                if Pos(LWord + FLines.LineBreak, LWordList) = 0 then { No duplicates }
                  LWordList := LWordList + LWord + FLines.LineBreak;
              LWord := ''
            end;
          end;
          LLinePos := LLineEndPos + 1;
        end;
        if (Length(LWord) > 1) then
          if Pos(LWord + FLines.LineBreak, LWordList) = 0 then { No duplicates }
            LWordList := LWordList + LWord + FLines.LineBreak;
      end;
    LStringList := TStringList.Create();
    LStringList.LineBreak := FLines.LineBreak;
    LStringList.Text := LWordList;
    LStringList.Sort();
    AStringList.Assign(LStringList);
    LStringList.Free();
  finally
    LOpenTokenSkipFoldRangeList.Free;
  end;
end;

procedure TCustomBCEditor.SyncEditActivated(const AData: Pointer);
begin
  Assert(FLines.SyncEdit and (FLines.SyncEditItems.Count > 0));

  UpdateCursor();
  InvalidateText();
end;

procedure TCustomBCEditor.SyncEditChecked(const AData: Pointer);
begin
  if (lsSyncEditAvailable in FLines.State) then
    InvalidateSyncEditButton();
end;

procedure TCustomBCEditor.TabsChanged(ASender: TObject);
begin
  if (FWordWrap) then
    InvalidateRows();
  InvalidateText();
end;

function TCustomBCEditor.TextBetween(const ABeginPosition, AEndPosition: TBCEditorLinesPosition): string;
var
  LSelArea: TBCEditorLinesArea;
begin
  LSelArea := FLines.SelArea;
  SelStart := PosToCharIndex(Min(ABeginPosition, AEndPosition));
  SelLength := SelStart + PosToCharIndex(Max(ABeginPosition, AEndPosition));
  Result := SelText;
  FLines.SelArea := LSelArea;
end;

function TCustomBCEditor.TextCaretPosition(): TBCEditorLinesPosition;
begin
  Result := FLines.CaretPosition;
end;

function TCustomBCEditor.TokenColumns(const AText: PChar;
  const ALength, AColumn: Integer): Integer;
begin
  if (Assigned(AText) and (AText^ = BCEDITOR_TAB_CHAR)) then
    Result := FTabs.Width - AColumn mod FTabs.Width
  else
    Result := ALength;
end;

function TCustomBCEditor.TokenWidth(const APaintHelper: TPaintHelper;
  const ALine: Integer;
  const AText: PChar; const ALength: Integer; const AColumn: Integer;
  const AToken: TBCEditorHighlighter.PTokenFind): Integer;
var
  LRect: TRect;
  LTextRect: TRect;
begin
  if (FFontPitchFixed
    and not (lfContainsWideChar in FLines.Items[ALine].Flags)
    and ((ALength <> 1) or (AText^ <> BCEDITOR_TAB_CHAR))) then
    Result := ALength * FSpaceWidth
  else
  begin
    LRect := Rect(0, 0, MaxInt, MaxInt);
    LTextRect := FMetrics.TextRect;
    ProcessToken(cjTokenWidth, APaintHelper, nil, LTextRect, mbLeft, [], Point(-1, -1), LRect,
      LinesPosition(-1, ALine), RowsPosition(AColumn, -1),
      AText, ALength, AToken);
    Result := LRect.Left;
  end;
end;

procedure TCustomBCEditor.ToggleSelectedCase(const ACase: TBCEditorCase = cNone);
var
  LCommand: TBCEditorCommand;
  LSelArea: TBCEditorLinesArea;
begin
  if AnsiUpperCase(SelText) <> AnsiUpperCase(FSelectedCaseText) then
  begin
    FSelectedCaseCycle := cUpper;
    FSelectedCaseText := SelText;
  end;
  if ACase <> cNone then
    FSelectedCaseCycle := ACase;

  BeginUpdate();

  LSelArea := LinesArea(FLines.SelBeginPosition, FLines.SelEndPosition);
  LCommand := ecNone;
  case FSelectedCaseCycle of
    cUpper: { UPPERCASE }
      LCommand := ecUpperCase;
    cLower: { lowercase }
      LCommand := ecLowerCase;
    cOriginal: { Original text }
      SelText := FSelectedCaseText;
  end;
  if FSelectedCaseCycle <> cOriginal then
    ProcessCommand(LCommand);
  FLines.SelArea := LSelArea;

  EndUpdate();

  Inc(FSelectedCaseCycle);
  if FSelectedCaseCycle > cOriginal then
    FSelectedCaseCycle := cUpper;
end;

procedure TCustomBCEditor.UMFindAllAreas(var AMessage: TMessage);
var
  LSearch: TBCEditorLines.TSearch;
begin
  if (FFindArea <> InvalidLinesArea) then
  begin
    LSearch := TBCEditorLines.TSearch.Create(FLines,
      FFindArea,
      foCaseSensitive in PBCEditorCommandDataFind(FLastSearchData)^.Options, foWholeWordsOnly in PBCEditorCommandDataFind(FLastSearchData)^.Options, foRegExpr in PBCEditorCommandDataFind(FLastSearchData)^.Options,
      PBCEditorCommandDataFind(FLastSearchData)^.Pattern);
    FFindArea := InvalidLinesArea;
    FFindState := fsAllAreas;

    FLines.StartSearch(LSearch, FLines.BOFPosition, True, False, False, FindExecuted);

    Sleep(GClientRefreshTime); // If search is fast enough, prevent double painting
  end;
end;

procedure TCustomBCEditor.UMFindWrapAround(var AMessage: TMessage);
var
  LSearch: TBCEditorLines.TSearch;
begin
  if (FFindArea <> InvalidLinesArea) then
  begin
    if (foBackwards in PBCEditorCommandDataFind(FLastSearchData)^.Options) then
    begin
      FFindArea.BeginPosition := FFindPosition;
      FFindPosition := FLines.EOFPosition;
    end
    else
    begin
      FFindArea.EndPosition := FFindPosition;
      FFindPosition := FLines.BOFPosition;
    end;

    LSearch := TBCEditorLines.TSearch.Create(FLines,
      FFindArea,
      foCaseSensitive in PBCEditorCommandDataFind(FLastSearchData)^.Options, foWholeWordsOnly in PBCEditorCommandDataFind(FLastSearchData)^.Options, foRegExpr in PBCEditorCommandDataFind(FLastSearchData)^.Options,
      PBCEditorCommandDataFind(FLastSearchData)^.Pattern);
    FFindState := fsWrappedAround;

    FLines.StartSearch(LSearch, FFindPosition, False, True, foBackwards in PBCEditorCommandDataFind(FLastSearchData)^.Options, FindExecuted);

    Sleep(GClientRefreshTime); // If search is fast enough, prevent double painting
  end;
end;

procedure TCustomBCEditor.UMFreeCompletionProposalPopup(var AMessage: TMessage);
begin
  if (Assigned(FCompletionProposalPopup)) then
    FreeAndNil(FCompletionProposalPopup);
end;

procedure TCustomBCEditor.WMRowAvailable(var AMessage: TMessage);
begin

end;

procedure TCustomBCEditor.UMUpdateScrollBars(var AMessage: TMessage);
begin
  UpdateScrollBars();
end;

procedure TCustomBCEditor.Undo();
begin
  ProcessCommand(ecUndo);
end;

procedure TCustomBCEditor.UnregisterCommandHandler(const AProc: Pointer;
  const AHandlerData: Pointer);
var
  LCommandHandler: TBCEditorHookedCommandHandler;
begin
  FillChar(LCommandHandler, SizeOf(LCommandHandler), 0);
  LCommandHandler.Proc := AProc;
  LCommandHandler.HandlerData := AHandlerData;
  FHookedCommandHandlers.Remove(LCommandHandler);
end;

procedure TCustomBCEditor.UnregisterCommandHandler(const AProc: TBCEditorHookedCommandObjectProc);
var
  LCommandHandler: TBCEditorHookedCommandHandler;
begin
  FillChar(LCommandHandler, SizeOf(LCommandHandler), 0);
  LCommandHandler.ObjectProc := AProc;
  FHookedCommandHandlers.Remove(LCommandHandler);
end;

function TCustomBCEditor.UpdateAction(Action: TBasicAction): Boolean;
begin
  Result := Focused;

  if (Result) then
    if Action is TEditCut then
      TEditCut(Action).Enabled := not FReadOnly and not FLines.SelArea.IsEmpty()
    else if Action is TEditCopy then
      TEditCopy(Action).Enabled := not FLines.SelArea.IsEmpty()
    else if Action is TEditPaste then
      TEditPaste(Action).Enabled := Focused() and CanPaste
    else if Action is TEditDelete then
      TEditDelete(Action).Enabled := not FReadOnly and not FLines.SelArea.IsEmpty()
    else if Action is TEditSelectAll then
      TEditSelectAll(Action).Enabled := (FLines.Count > 0)
    else if Action is TEditUndo then
      TEditUndo(Action).Enabled := not FReadOnly and FLines.CanUndo
    else if Action is TSearchFindNext then
      TSearchFindNext(Action).Enabled := Assigned(FLastSearchData)
    else if Action is TSearchReplace then
      TSearchReplace(Action).Enabled := (FLines.Count > 0)
    else
      Result := inherited;
end;

procedure TCustomBCEditor.UpdateCaret();
var
  LCompForm: TCompositionForm;
  LRect: TRect;
  LImc: HIMC;
begin
  if (not (csDesigning in ComponentState)
    and HandleAllocated) then
  begin
    if ((FLineHeight > 0)
      and InvalidPoint(FCaretPos)) then
      FCaretPos := RowsToClient(FRows.CaretPosition, True);

    LRect := FMetrics.ClientRect;
    Inc(LRect.Left, FLeftMarginWidth);
    if (not LRect.Contains(FCaretPos)
      or not Focused() and not Assigned(FCompletionProposalPopup)) then
    begin
      if (FCaretVisible) then
      begin
        DestroyCaret();
        FCaretVisible := False;
      end;
    end
    else
    begin
      if (not FCaretVisible) then
      begin
        CreateCaret(WindowHandle, 0, FCaretWidth, FLineHeight);
        ShowCaret(WindowHandle);
        FCaretVisible := True;
      end;

      Windows.SetCaretPos(FCaretPos.X, FCaretPos.Y);

      if (GImmEnabled) then
      begin
        LCompForm.dwStyle := CFS_POINT;
        LCompForm.ptCurrentPos := FCaretPos;
        LImc := ImmGetContext(WindowHandle);
        ImmSetCompositionWindow(LImc, @LCompForm);
        ImmReleaseContext(WindowHandle, LImc);
      end;
    end;

    FState := FState - [esCaretInvalid];
  end;
end;

procedure TCustomBCEditor.UpdateCursor();
begin
  PostMessage(WindowHandle, WM_SETCURSOR, WindowHandle, MakeLong(HTCLIENT, WM_MOUSEMOVE));
end;

procedure TCustomBCEditor.UpdateLineInRows(const ALine: Integer);
var
  LRow: Integer;
begin
  if (FRows.Count > 0) then
  begin
    LRow := FLines.Items[ALine].FirstRow;

    if (LRow >= 0) then
    begin
      DeleteLineFromRows(ALine);

      FPaintHelper.BeginDraw(Canvas.Handle);
      try
        InsertLineIntoRows(FPaintHelper, nil, ALine, LRow);
      finally
        FPaintHelper.EndDraw();
      end;
    end;
  end;
end;

procedure TCustomBCEditor.UpdateMetrics();
begin
  if (not HandleAllocated) then
    FMetrics.ClientRect := Rect(-1, -1, -1, -1)
  else
    FMetrics.ClientRect := ClientRect;

  FLeftMarginWidth := 0;
  if (FLeftMargin.Bookmarks.Visible or FLeftMargin.Marks.Visible) then
  begin
    FMetrics.MarksPanelRect := Rect(FLeftMarginWidth, 0, FLeftMarginWidth + FMarksPanelWidth, FMetrics.ClientRect.Height);
    Inc(FLeftMarginWidth, FMarksPanelWidth);
  end
  else
    FMetrics.MarksPanelRect := Rect(-1, -1, -1, -1);
  if (FLeftMargin.LineNumbers.Visible) then
  begin
    FMetrics.LineNumbersRect := Rect(FLeftMarginWidth, 0, FLeftMarginWidth + FLineNumbersWidth, FMetrics.ClientRect.Height);
    Inc(FLeftMarginWidth, FLineNumbersWidth);
  end
  else
    FMetrics.LineNumbersRect := Rect(-1, -1, -1, -1);
  if (FLeftMargin.LineState.Visible) then
  begin
    FMetrics.LineStateRect := Rect(FLeftMarginWidth, 0, FLeftMarginWidth + FLineStateWidth, FMetrics.ClientRect.Height);
    Inc(FLeftMarginWidth, FLineStateWidth);
  end
  else
    FMetrics.LineStateRect := Rect(-1, -1, -1, -1);
  if (FLeftMargin.CodeFolding.Visible) then
  begin
    FMetrics.CodeFoldingRect := Rect(FLeftMarginWidth, 0, FLeftMarginWidth + FCodeFoldingWidth, FMetrics.ClientRect.Height);
    Inc(FLeftMarginWidth, FCodeFoldingWidth);
  end
  else
    FMetrics.CodeFoldingRect := Rect(-1, -1, -1, -1);
  if (FLeftMarginWidth > 0) then
  begin
    FMetrics.LeftMarginBorderRect := Rect(FLeftMarginWidth, 0, FLeftMarginWidth + FLeftMarginBorderWidth, FMetrics.ClientRect.Height);
    Inc(FLeftMarginWidth, FLeftMarginBorderWidth);
  end;

  FMetrics.TextRect := Rect(FLeftMarginWidth, 0, FMetrics.ClientRect.Width, FMetrics.ClientRect.Height);

  if (FLineHeight > 0) then
  begin
    FUsableRows := Max(1, FMetrics.ClientRect.Height div FLineHeight);
    if (FMetrics.ClientRect.Height = FUsableRows * FLineHeight) then
      FVisibleRows := FUsableRows
    else
      FVisibleRows := FUsableRows + 1;
  end;
end;

procedure TCustomBCEditor.UpdateScrollBars();
var
  LHorzScrollInfo: TScrollInfo;
  LVertScrollInfo: TScrollInfo;
begin
  LVertScrollInfo.cbSize := SizeOf(ScrollInfo);
  LVertScrollInfo.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  LVertScrollInfo.nMin := 0;
  if (FRows.Count = 0) then
    LVertScrollInfo.nMax := 0
  else
    LVertScrollInfo.nMax := Max(FRows.CaretPosition.Row, FRows.Count - 1);
  LVertScrollInfo.nPage := FUsableRows;
  LVertScrollInfo.nPos := FTopRow;
  LVertScrollInfo.nTrackPos := 0;
  SetScrollInfo(WindowHandle, SB_VERT, LVertScrollInfo, TRUE);
  // In WM_VSCROLL Message Pos is a SmallInt value... :-/
  if (LVertScrollInfo.nMax <= High(SmallInt)) then
    FVertScrollBarDivider := 1
  else
  begin
    FVertScrollBarDivider := LVertScrollInfo.nMax div (High(SmallInt) + 1) + 1;
    LVertScrollInfo.nMax := LVertScrollInfo.nMax div FVertScrollBarDivider;
    LVertScrollInfo.nPage := LVertScrollInfo.nPage div Cardinal(FVertScrollBarDivider);
    LVertScrollInfo.nPos := LVertScrollInfo.nPos div FVertScrollBarDivider;
  end;
  if (not (rsBuilding in FRows.State)
    or (LVertScrollInfo.nMax >= Integer(LVertScrollInfo.nPage))) then
    if (LVertScrollInfo.nMax >= Integer(LVertScrollInfo.nPage)) then
      EnableScrollBar(WindowHandle, SB_VERT, ESB_ENABLE_BOTH)
    else if (not FHideScrollBars) then
    begin
      ShowScrollBar(WindowHandle, SB_VERT, True);
      EnableScrollBar(WindowHandle, SB_VERT, ESB_DISABLE_BOTH);
    end;

  LHorzScrollInfo.cbSize := SizeOf(ScrollInfo);
  LHorzScrollInfo.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  LHorzScrollInfo.nMin := 0;
  LHorzScrollInfo.nMax := FRows.MaxWidth;
  if ((FRows.Count = 0)
    or (FRows.CaretPosition.Row >= FRows.Count)
    or (FRows.Items[FRows.CaretPosition.Row].Length = 0)) then
    LHorzScrollInfo.nMax := Max(LHorzScrollInfo.nMax, FRows.CaretPosition.Column * FSpaceWidth)
  else if (FRows.CaretPosition.Column > FRows.Items[FRows.CaretPosition.Row].Length) then
    LHorzScrollInfo.nMax := Max(LHorzScrollInfo.nMax, FRows.MaxWidth + (FRows.CaretPosition.Column - FRows.Items[FRows.CaretPosition.Row].Length) * FSpaceWidth);
  if (eoShowSpecialChars in FOptions) then
    Inc(LHorzScrollInfo.nMax, FLineBreakSignWidth);
  Inc(LHorzScrollInfo.nMax, FCaretWidth);
  LHorzScrollInfo.nPage := FMetrics.TextRect.Width;
  LHorzScrollInfo.nPos := FTextPos.X;
  LHorzScrollInfo.nTrackPos := 0;
  // In WM_HSCROLL Message Pos is a SmallInt value... :-/
  if (LHorzScrollInfo.nMax <= High(SmallInt)) then
    FHorzScrollBarDivider := 1
  else
  begin
    FHorzScrollBarDivider := LHorzScrollInfo.nMax div (High(SmallInt) + 1) + 1;
    LHorzScrollInfo.nMax := LHorzScrollInfo.nMax div FHorzScrollBarDivider;
    LHorzScrollInfo.nPage := LHorzScrollInfo.nPage div Cardinal(FHorzScrollBarDivider);
    LHorzScrollInfo.nPos := LHorzScrollInfo.nPos div FHorzScrollBarDivider;
  end;
  SetScrollInfo(WindowHandle, SB_HORZ, LHorzScrollInfo, TRUE);
  if (LHorzScrollInfo.nMax >= Integer(LHorzScrollInfo.nPage)) then
    EnableScrollBar(WindowHandle, SB_HORZ, ESB_ENABLE_BOTH)
  else if (not FHideScrollBars) then
  begin
    ShowScrollBar(WindowHandle, SB_HORZ, True);
    EnableScrollBar(WindowHandle, SB_HORZ, ESB_DISABLE_BOTH);
  end;

  if (not (esScrolling in FState)) then
    FScrollingEnabled := (eoMiddleClickScrolling in FOptions)
      and ((LVertScrollInfo.nMax >= Integer(LVertScrollInfo.nPage))
        or (LHorzScrollInfo.nMax >= Integer(LHorzScrollInfo.nPage)));

  FState := FState - [esScrollBarsInvalid];
end;

procedure TCustomBCEditor.WMClear(var AMessage: TWMClear);
begin
  SelText := '';
end;

procedure TCustomBCEditor.WMCommand(var AMessage: TWMCommand);
begin
  if ((AMessage.NotifyCode = 0) and (AMessage.Ctl = 0)) then
    case (AMessage.ItemID) of
      WM_UNDO,
      WM_CUT,
      WM_COPY,
      WM_PASTE,
      WM_CLEAR: Perform(AMessage.ItemID, 0, 0);
      EM_SETSEL: Perform(AMessage.ItemID, 0, -1);
      WM_APP + 0: { Right to left Reading order }
        MessageBox(WindowHandle, 'Does it make sense to heave a right to left order this editor?' + #10
          + 'If yes, please explaint it to the developer of the BCEditor at: https://github.com/bonecode/BCEditor/',
          'Help wanted',
          MB_OK);
      WM_APP + 1: { Show Unicode control characters }
        begin
          FUCCVisible := not FUCCVisible;
          InvalidateText();
        end;
      WM_APP + 2: Perform(WM_CHAR, Ord(BCEditor_UCC_ZWJ), 0); { ZWJ Unicode control character }
      WM_APP + 3: Perform(WM_CHAR, Ord(BCEditor_UCC_ZWNJ), 0); { ZWNJ Unicode control character }
      WM_APP + 4: Perform(WM_CHAR, Ord(BCEditor_UCC_LRM), 0); { LRM Unicode control character }
      WM_APP + 5: Perform(WM_CHAR, Ord(BCEditor_UCC_RLM), 0); { RLM Unicode control character }
      WM_APP + 6: Perform(WM_CHAR, Ord(BCEditor_UCC_LRE), 0); { LRE Unicode control character }
      WM_APP + 7: Perform(WM_CHAR, Ord(BCEditor_UCC_RLE), 0); { RLE Unicode control character }
      WM_APP + 8: Perform(WM_CHAR, Ord(BCEditor_UCC_LRO), 0); { LRO Unicode control character }
      WM_APP + 9: Perform(WM_CHAR, Ord(BCEditor_UCC_RLO), 0); { RLO Unicode control character }
      WM_APP + 10: Perform(WM_CHAR, Ord(BCEditor_UCC_PDF), 0); { PDF Unicode control character }
      WM_APP + 11: Perform(WM_CHAR, Ord(BCEditor_UCC_NADS), 0); { NADS Unicode control character }
      WM_APP + 12: Perform(WM_CHAR, Ord(BCEditor_UCC_NODS), 0); { NODS Unicode control character }
      WM_APP + 13: Perform(WM_CHAR, Ord(BCEditor_UCC_ASS), 0); { ASS Unicode control character }
      WM_APP + 14: Perform(WM_CHAR, Ord(BCEditor_UCC_ISS), 0); { ISS Unicode control character }
      WM_APP + 15: Perform(WM_CHAR, Ord(BCEditor_UCC_AAFS), 0); { AAFS Unicode control character }
      WM_APP + 16: Perform(WM_CHAR, Ord(BCEditor_UCC_IAFS), 0); { IAFS Unicode control character }
      WM_APP + 17: Perform(WM_CHAR, Ord(BCEditor_UCC_RS), 0); { RS Unicode control character }
      WM_APP + 18: Perform(WM_CHAR, Ord(BCEditor_UCC_US), 0); { US Unicode control character }
      WM_APP + 20: { Open IME }
        MessageBox(WindowHandle, 'The developer of the BCEditor don''t know, how to implement this feature.' + #10
          + 'If you know it, please contact him at: https://github.com/bonecode/BCEditor/',
          'Help wanted',
          MB_OK);
      WM_APP + 21: ; { Reconversion }
      else
        inherited;
    end
  else
    inherited;
end;

procedure TCustomBCEditor.WMContextMenu(var AMessage: TWMContextMenu);
var
  LBuffer: array [0 .. 100] of Char;
  LClient: TPoint;
  LIndex: Integer;
  LIndex2: Integer;
  LInstance: THandle;
  LLen: Integer;
  LMenu: HMENU;
  LMenuItemInfo: MENUITEMINFO;
  LNewCaretPosition: TBCEditorLinesPosition;
begin
  LClient := ScreenToClient(Point(AMessage.XPos, AMessage.YPos));

  if (FLeftMargin.Marks.Visible
    and (FMetrics.MarksPanelRect.Left <= LClient.X) and (LClient.X <= FMetrics.MarksPanelRect.Right)
    and Assigned(FMarksPanelPopupMenu)) then
  begin
    FMarksPanelPopupMenu.Popup(AMessage.XPos, AMessage.YPos);
    AMessage.Result := LRESULT(TRUE);
  end
  else if (LClient.X > FLeftMarginWidth) then
  begin
    LNewCaretPosition := ClientToLines(LClient.X, LClient.Y);

    if (Assigned(PopupMenu)) then
      inherited
    else
    begin
      if (FPopupMenu = 0) then
      begin
        LInstance := GetModuleHandle('User32.dll');
        LMenu := LoadMenu(LInstance, MAKEINTRESOURCE(1));
        if ((LMenu > 0) and (GetMenuItemCount(LMenu) = 1)) then
        begin
          LMenu := GetSubMenu(LMenu, 0);
          LMenuItemInfo.cbSize := SizeOf(LMenuItemInfo);
          LMenuItemInfo.fMask := MIIM_ID or MIIM_STATE or MIIM_SUBMENU;
          if ((LMenu > 0) and GetMenuItemInfo(LMenu, 0, TRUE, LMenuItemInfo)) then
          begin
            FPopupMenu := LMenu;
            for LIndex := 0 to GetMenuItemCount(FPopupMenu) - 1 do
              if (GetMenuItemInfo(FPopupMenu, LIndex, TRUE, LMenuItemInfo)) then
                case (LMenuItemInfo.wID) of
                  WM_APP + 1: { Show Unicode control characters }
                    begin
                      LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED;
                      SetMenuItemInfo(FPopupMenu, LIndex, TRUE, LMenuItemInfo);
                    end;
                  WM_APP + 19: { Insert Unicode control character }
                    begin
                      LMenu := LMenuItemInfo.hSubMenu;
                      for LIndex2 := 0 to GetMenuItemCount(LMenu) - 1 do
                        if (GetMenuItemInfo(LMenu, LIndex2, TRUE, LMenuItemInfo)) then
                        begin
                          LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED;
                          SetMenuItemInfo(LMenu, LIndex2, TRUE, LMenuItemInfo);
                        end;
                    end;
                end;
            LLen := LoadString(LInstance, 700, @LBuffer[0], Length(LBuffer));
            if (LLen > 0) then
            begin
              AppendMenu(FPopupMenu, MF_SEPARATOR, 0, nil);
              AppendMenu(FPopupMenu, MF_STRING, WM_APP + 20, @LBuffer[0]);
              LLen := LoadString(LInstance, 705, @LBuffer[0], Length(LBuffer));
              if (LLen > 0) then
                AppendMenu(FPopupMenu, MF_STRING, WM_APP + 21, @LBuffer[0]);
            end;
          end;
        end;
      end;
      if (FPopupMenu <> 0) then
      begin
        LMenuItemInfo.cbSize := SizeOf(LMenuItemInfo);
        LMenuItemInfo.fMask := MIIM_ID or MIIM_STATE;
        for LIndex := 0 to GetMenuItemCount(FPopupMenu) - 1 do
          if (GetMenuItemInfo(FPopupMenu, LIndex, TRUE, LMenuItemInfo)) then
          begin
            case (LMenuItemInfo.wID) of
              WM_UNDO:
                if (CanUndo) then
                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED
                else
                  LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED;
              WM_CUT:
                if (not FLines.SelArea.IsEmpty() and not FReadOnly) then
                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED
                else
                  LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED;
              WM_COPY:
                if (not FLines.SelArea.IsEmpty()) then
                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED
                else
                  LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED;
              WM_PASTE:
                if (CanPaste) then
                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED
                else
                  LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED;
              WM_CLEAR:
                if (not FLines.SelArea.IsEmpty() and not FReadOnly) then
                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED
                else
                  LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED;
              EM_SETSEL:
                if ((FLines.SelArea <> FLines.Area) and (FLines.Count > 0)) then
                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED
                else
                  LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED;
              WM_APP + 0: { Right to left Reading order }
                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED;
//              WM_APP + 1: { Show Unicode control characters }
//                if (not FUCCVisible) then
//                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_CHECKED
//                else
//                  LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_CHECKED;
//              WM_APP + 19: { Insert Unicode control character }
//                if (FReadOnly) then
//                  LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED
//                else
//                  LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED;
              WM_APP + 20: { Open IME }
                LMenuItemInfo.fState := LMenuItemInfo.fState and not MFS_DISABLED;
              WM_APP + 21: { Reconversion }
                LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED
              else
                LMenuItemInfo.fState := LMenuItemInfo.fState or MFS_DISABLED;
            end;
            SetMenuItemInfo(FPopupMenu, LIndex, TRUE, LMenuItemInfo);
          end;

        TrackPopupMenu(FPopupMenu, 2, AMessage.XPos, AMessage.YPos, 0, WindowHandle, nil);
      end;
    end;
  end;
end;

procedure TCustomBCEditor.WMCopy(var AMessage: TWMCopy);
begin
  if (FLines.SelArea.IsEmpty()) then
    AMessage.Result := LRESULT(FALSE)
  else
  begin
    CopyToClipboard();
    AMessage.Result := LRESULT(TRUE);
  end;
end;

procedure TCustomBCEditor.WMCut(var AMessage: TWMCut);
begin
  if (FReadOnly or FLines.SelArea.IsEmpty()) then
    AMessage.Result := LRESULT(FALSE)
  else
  begin
    CutToClipboard();
    AMessage.Result := LRESULT(TRUE);
  end;
end;

procedure TCustomBCEditor.WMEraseBkgnd(var AMessage: TWMEraseBkgnd);
begin
  AMessage.Result := 1;
end;

procedure TCustomBCEditor.WMGetDlgCode(var AMessage: TWMGetDlgCode);
begin
  inherited;

  AMessage.Result := AMessage.Result or DLGC_WANTARROWS or DLGC_WANTMESSAGE or DLGC_HASSETSEL or DLGC_WANTCHARS;
  if (FWantTabs) then
    AMessage.Result := AMessage.Result or DLGC_WANTTAB;
  if (FWantReturns) then
    AMessage.Result := AMessage.Result or DLGC_WANTALLKEYS;
end;

procedure TCustomBCEditor.WMGetText(var AMessage: TWMGetText);
var
  LText: string;
begin
  if (FFmtLines) then
    LText := FRows.FmtText
  else
    LText := FLines.Text;
  StrLCopy(PChar(AMessage.Text), PChar(LText), AMessage.TextMax - 1);
  AMessage.Result := StrLen(PChar(AMessage.Text));
end;

procedure TCustomBCEditor.WMGetTextLength(var AMessage: TWMGetTextLength);
begin
  if ((csDocking in ControlState) or (csDestroying in ComponentState)) then
    AMessage.Result := 0
  else
    AMessage.Result := FLines.TextLength;
end;

procedure TCustomBCEditor.WMHScroll(var AMessage: TWMScroll);
begin
  inherited;

  case (AMessage.ScrollCode) of
    SB_LINELEFT:
      ScrollTo(FTextPos.X - Integer(FWheelScrollChars) * FSpaceWidth, FTextPos.Y);
    SB_LINERIGHT:
      ScrollTo(FTextPos.X + Integer(FWheelScrollChars) * FSpaceWidth, FTextPos.Y);
    SB_PAGELEFT:
      ScrollTo(FTextPos.X - FMetrics.TextRect.Width, FTextPos.Y);
    SB_PAGERIGHT:
      ScrollTo(FTextPos.X + FMetrics.TextRect.Width, FTextPos.Y);
    SB_THUMBPOSITION,
    SB_THUMBTRACK:
      ScrollTo(AMessage.Pos * FHorzScrollBarDivider, FTextPos.Y);
    SB_LEFT:
      ScrollTo(0, FTextPos.Y);
    SB_RIGHT:
      ScrollTo(FRows.MaxWidth - FMetrics.TextRect.Width, FTextPos.Y);
  end;

  AMessage.Result := 0;
end;

procedure TCustomBCEditor.WMIMEChar(var AMessage: TMessage);
begin
  { Do nothing here, the IME string is retrieved in WMIMEComposition
    Handling the WM_IME_CHAR message stops Windows from sending WM_CHAR messages while using the IME }
end;

procedure TCustomBCEditor.WMIMEComposition(var AMessage: TMessage);
var
  LImc: HIMC;
  LSize: Integer;
  LText: string;
begin
  if ((AMessage.LParam and GCS_RESULTSTR <> 0)
    and (FIMEStatus and EIMES_GETCOMPSTRATONCE = 0)) then
  begin
    LImc := ImmGetContext(WindowHandle);
    try
      LSize := ImmGetCompositionString(LImc, GCS_RESULTSTR, nil, 0);
      { ImeCount is always the size in bytes, also for Unicode }
      SetLength(LText, LSize div SizeOf(Char));
      ImmGetCompositionString(LImc, GCS_RESULTSTR, PChar(LText), LSize);
      ProcessCommand(ecText, TBCEditorCommandDataText.Create(LText));
    finally
      ImmReleaseContext(WindowHandle, LImc);
    end;
  end;

  inherited;
end;

procedure TCustomBCEditor.WMIMENotify(var AMessage: TMessage);
var
  LImc: HIMC;
  LLogFont: TLogFont;
begin
  case (AMessage.wParam) of
    IMN_SETOPENSTATUS:
      begin
        LImc := ImmGetContext(WindowHandle);
        GetObject(Font.Handle, SizeOf(TLogFont), @LLogFont);
        ImmSetCompositionFont(LImc, @LLogFont);
        ImmReleaseContext(WindowHandle, LImc);
      end;
  end;

  inherited;
end;

procedure TCustomBCEditor.WMMouseHWheel(var AMessage: TWMMouseWheel);
begin
  if (esScrolling in FState) then
    ProcessClient(cjMouseDown, nil, nil, FMetrics.ClientRect, mbMiddle, [], FScrollingPoint);

  if (AMessage.WheelDelta < 0) then
    ScrollTo(FTextPos.X - FHorzScrollBarDivider * FSpaceWidth, FTextPos.Y)
  else if (AMessage.WheelDelta > 0) then
    ScrollTo(FTextPos.X + FHorzScrollBarDivider * FSpaceWidth, FTextPos.Y);

  AMessage.Result := 1;
end;

procedure TCustomBCEditor.WMNCPaint(var AMessage: TWMNCPaint);
var
  LRect: TRect;
  LRgn: HRGN;
begin
  if (StyleServices.Enabled
    and (GetWindowLong(WindowHandle, GWL_EXSTYLE) and WS_EX_CLIENTEDGE <> 0)) then
  begin
    GetWindowRect(WindowHandle, LRect);
    InflateRect(LRect, -GetSystemMetrics(SM_CXEDGE), -GetSystemMetrics(SM_CYEDGE));
    LRgn := CreateRectRgnIndirect(LRect);
    DefWindowProc(WindowHandle, AMessage.Msg, WPARAM(LRgn), 0);
    DeleteObject(LRgn);
  end
  else
    DefaultHandler(AMessage);

  if (StyleServices.Enabled) then
    StyleServices.PaintBorder(Self, False);
end;

procedure TCustomBCEditor.WMKillFocus(var AMessage: TWMKillFocus);
begin
  if (Assigned(FHintWindow)) then
    FreeAndNil(FHintWindow);

  inherited;

  NotifyParent(EN_KILLFOCUS);

  if (not Assigned(FCompletionProposalPopup)) then
    UpdateCaret();

  if (HideSelection and not FLines.SelArea.IsEmpty()) then
    InvalidateText();
end;

procedure TCustomBCEditor.WMPaint(var AMessage: TWMPaint);
begin
  TWMPrint(AMessage).Flags := PRF_CHECKVISIBLE or PRF_CHILDREN or PRF_CLIENT
    or PRF_NONCLIENT or PRF_OWNED;
  if (csOpaque in ControlStyle) then
    TWMPrint(AMessage).Flags := TWMPrint(AMessage).Flags or PRF_ERASEBKGND;

  WMPrint(TWMPrint(AMessage));
end;

procedure TCustomBCEditor.WMPaste(var AMessage: TWMPaste);
begin
  if (FReadOnly or not IsClipboardFormatAvailable(CF_UNICODETEXT)) then
    AMessage.Result := LRESULT(FALSE)
  else
  begin
    PasteFromClipboard();
    AMessage.Result := LRESULT(TRUE);
  end;
end;

procedure TCustomBCEditor.WMPrint(var AMessage: TWMPrint);
var
  LPaintStruct: TPaintStruct;
  LPaintVar: TPaintVar;
begin
  if (esTextUpdated in FState) then
  begin
    NotifyParent(EN_UPDATE);
    Exclude(FState, esTextUpdated);
  end;

  BeginPaint(WindowHandle, LPaintStruct);
  try
    if (not DoubleBuffered) then
    begin
      FPaintHelper.BeginDraw(LPaintStruct.hdc);
      try
        PaintTo(FPaintHelper, LPaintStruct.rcPaint)
      finally
        FPaintHelper.EndDraw();
      end;
    end
    else
    begin
      if (not Assigned(FDoubleBufferBitmap)) then
      begin
        Canvas.Handle; // Allocate Handle
        Perform(CM_DOUBLEBUFFEREDCHANGED, 0, 0);
      end;

      FPaintHelper.BeginDraw(FDoubleBufferBitmap.Canvas.Handle);
      try
        if (esDoubleBufferInvalid in FState) then
        begin
          PaintTo(FPaintHelper, FMetrics.ClientRect, False);
          Exclude(FState, esDoubleBufferInvalid);
          FDoubleBufferUpdateRect := Rect(-1, -1, -1, -1);
        end
        else if (LPaintStruct.rcPaint.IntersectsWith(FDoubleBufferUpdateRect)) then
        begin
          PaintTo(FPaintHelper, FDoubleBufferUpdateRect, False);
          FDoubleBufferUpdateRect := Rect(-1, -1, -1, -1);
        end;
      finally
        FPaintHelper.EndDraw();
      end;

      if (FSyncEditButtonRect.IsEmpty() and FScrollingRect.IsEmpty()) then
        BitBlt(LPaintStruct.hdc,
          LPaintStruct.rcPaint.Left, LPaintStruct.rcPaint.Top, LPaintStruct.rcPaint.Width, LPaintStruct.rcPaint.Height,
          FDoubleBufferBitmap.Canvas.Handle,
          LPaintStruct.rcPaint.Left, LPaintStruct.rcPaint.Top,
          SRCCOPY)
      else
      begin
        FPaintHelper.BeginDraw(FDoubleBufferOverlayBitmap.Canvas.Handle);
        try
          BitBlt(FDoubleBufferOverlayBitmap.Canvas.Handle,
            LPaintStruct.rcPaint.Left, LPaintStruct.rcPaint.Top, LPaintStruct.rcPaint.Width, LPaintStruct.rcPaint.Height,
            FDoubleBufferBitmap.Canvas.Handle,
            LPaintStruct.rcPaint.Left, LPaintStruct.rcPaint.Top,
            SRCCOPY);
          FillChar(LPaintVar, SizeOf(LPaintVar), 0);
          LPaintVar.Graphics := TGPGraphics.Create(FDoubleBufferOverlayBitmap.Canvas.Handle);
          ProcessClient(cjPaintOverlays,
            FPaintHelper, @LPaintVar, FSyncEditButtonRect,
            mbLeft, [], Point(-1, -1), True);
          ProcessClient(cjPaintOverlays,
            FPaintHelper, @LPaintVar, FScrollingRect,
            mbLeft, [], Point(-1, -1), True);
          LPaintVar.Graphics.Free();
          BitBlt(LPaintStruct.hdc,
            LPaintStruct.rcPaint.Left, LPaintStruct.rcPaint.Top, LPaintStruct.rcPaint.Width, LPaintStruct.rcPaint.Height,
            FDoubleBufferOverlayBitmap.Canvas.Handle,
            LPaintStruct.rcPaint.Left, LPaintStruct.rcPaint.Top,
            SRCCOPY);
        finally
          FPaintHelper.EndDraw();
        end;
      end;
    end;
  finally
    EndPaint(WindowHandle, LPaintStruct);
  end;

  if (FState * [esScrollBarsInvalid, esSizeChanged] <> []) then
    UpdateScrollBars();

  if ((FState * [esCaretInvalid] <> [])
    and ((FRows.Count > 0) or not (esSizeChanged in FState))) then
    UpdateCaret();

  if (FLeftMargin.CodeFolding.Visible
    and (esCodeFoldingInvalid in FState)) then
    SetTimer(WindowHandle, tiCodeFolding, FLeftMargin.CodeFolding.DelayInterval, nil);
end;

procedure TCustomBCEditor.WMSetCursor(var AMessage: TWMSetCursor);
var
  LCursorPoint: TPoint;
begin
  if ((AMessage.CursorWnd = WindowHandle)
    and (AMessage.HitTest = HTCLIENT)
    and (FLineHeight > 0)
    and (FRowsWanted.What = rwNothing)
    and not (csDesigning in ComponentState)) then
  begin
    GetCursorPos(LCursorPoint);
    LCursorPoint := ScreenToClient(LCursorPoint);
    ProcessClient(cjMouseMove, nil, nil, FMetrics.ClientRect, mbLeft, [], LCursorPoint);
    AMessage.Result := LRESULT(TRUE);
  end
  else
    inherited;
end;

procedure TCustomBCEditor.WMSetFocus(var AMessage: TWMSetFocus);
begin
  inherited;

  NotifyParent(EN_SETFOCUS);

  UpdateCaret();

  if (HideSelection and not FLines.SelArea.IsEmpty()) then
    InvalidateText();

  if (Assigned(FCompletionProposalPopup)) then
    PostMessage(WindowHandle, UM_FREE_COMPLETIONPROPOSALPOPUP, 0, 0);
end;

procedure TCustomBCEditor.WMSettingChange(var AMessage: TWMSettingChange);
begin
  case (AMessage.Flag) of
    // This didn't work on my end. :-(
    SPI_SETDOUBLECLICKTIME:
      FDoubleClickTime := GetDoubleClickTime();
    SPI_GETWHEELSCROLLCHARS:
      if (not SystemParametersInfo(SPI_GETWHEELSCROLLCHARS, 0, @FWheelScrollChars, 0)) then
        FWheelScrollChars := 3;
  end;
end;

procedure TCustomBCEditor.WMSetText(var AMessage: TWMSetText);
begin
  if (FReadOnly) then
    AMessage.Result := LPARAM(FALSE)
  else
  begin
    AMessage.Result := LPARAM(TRUE);
    Text := StrPas(AMessage.Text);
  end;
end;

procedure TCustomBCEditor.WMStyleChanged(var AMessage: TWMStyleChanged);
begin
  inherited;

  if (AMessage.StyleType = WPARAM(GWL_STYLE)) then
  begin
    SetReadOnly(AMessage.StyleStruct^.styleNew and ES_READONLY <> 0);
    SetWantReturns(AMessage.StyleStruct^.styleNew and ES_WANTRETURN <> 0);
    SetHideSelection(AMessage.StyleStruct^.styleNew and ES_NOHIDESEL = 0);

    if (not Focused() and not FLines.SelArea.IsEmpty()) then
      InvalidateText();
  end
  else if (AMessage.StyleType = WPARAM(GWL_EXSTYLE)) then
  begin
    FNoParentNotify := AMessage.StyleStruct^.styleNew and WS_EX_NOPARENTNOTIFY <> 0;
    if (AMessage.StyleStruct^.styleNew and WS_EX_ACCEPTFILES = 0) then
      SetOptions(FOptions - [eoDropFiles])
    else
      SetOptions(FOptions + [eoDropFiles]);
  end;
end;

procedure TCustomBCEditor.WMSysChar(var AMessage: TMessage);
begin
  if (AMessage.LParam and (1 shl 29) <> 0) then
    // Do nothing to prevent a beep sound
  else
    inherited;
end;

procedure TCustomBCEditor.WMTimer(var Msg: TWMTimer);
begin
  case (Msg.TimerID) of
    tiCodeFolding:
      begin
        KillTimer(WindowHandle, Msg.TimerID);
        ScanCodeFolding();
      end;
    tiShowHint:
      begin
        KillTimer(WindowHandle, Msg.TimerID);
        if (ShowHint
          and not (esScrolling in FState)) then
          ProcessClient(cjHint, nil, nil, FMetrics.ClientRect, mbLeft, [], FCursorPoint);
      end;
    tiScrolling:
      ProcessClient(cjScrolling, nil, nil, FMetrics.TextRect, mbLeft, [], FCursorPoint);
    tiScroll:
      ProcessClient(cjMouseMove, nil, nil, FMetrics.TextRect, mbLeft, [], FCursorPoint);
    tiCompletionProposal:
      begin
        KillTimer(WindowHandle, Msg.TimerID);
        DoCompletionProposal();
      end;
  end;
end;

procedure TCustomBCEditor.WMUndo(var AMessage: TWMUndo);
begin
  FLines.Undo();
end;

procedure TCustomBCEditor.WMVScroll(var AMessage: TWMScroll);
var
  LLine: Integer;
  LCursorPos: TPoint;
  LHint: string;
  LRect: TRect;
begin
  case (AMessage.ScrollCode) of
    SB_LINEUP:
      ScrollTo(FTextPos.X, FTextPos.Y - 1 * FLineHeight);
    SB_LINEDOWN:
      ScrollTo(FTextPos.X, FTextPos.Y + 1 * FLineHeight);
    SB_PAGEUP:
      ScrollTo(FTextPos.X, FTextPos.Y - FUsableRows * FLineHeight);
    SB_PAGEDOWN:
      ScrollTo(FTextPos.X, FTextPos.Y + FUsableRows * FLineHeight);
    SB_TOP:
      ScrollTo(FTextPos.X, 0 * FLineHeight);
    SB_BOTTOM:
      ScrollTo(FTextPos.X, (FRows.Count - 1) * FLineHeight);
    SB_THUMBPOSITION,
    SB_THUMBTRACK:
      begin
        ScrollTo(FTextPos.X, AMessage.Pos * FVertScrollBarDivider * FLineHeight);

        if (FLeftMargin.LineNumbers.Visible and ShowHint) then
        begin
          if (not Assigned(FHintWindow)) then
          begin
            FHintWindow := THintWindow.Create(Self);
            FHintWindow.Color := clInfoBk;
          end;

          if (FTopRow < FRows.Count) then
            LLine := FRows.Items[FTopRow].Line + FLeftMargin.LineNumbers.Offset
          else
            LLine := FTopRow - FRows.Count + FLines.Count  + FLeftMargin.LineNumbers.Offset;

          LHint := Format(SBCEditorScrollInfo, [LLine]);

          LRect := FHintWindow.CalcHintRect(FMetrics.ClientRect.Width, LHint, nil);
          LRect.Offset(ClientToScreen(Point(FMetrics.ClientRect.Width - LRect.Width, 0)));

          if (GetCursorPos(LCursorPos)) then
            LRect.Offset(0,
              Min(FMetrics.ClientRect.Height - GetSystemMetrics(SM_CYVSCROLL), Max(GetSystemMetrics(SM_CYVSCROLL), ScreenToClient(LCursorPos).Y))
              - LRect.Height shr 1);

          FHintWindow.ActivateHint(LRect, LHint);
        end;
      end;
    SB_ENDSCROLL:
      if (Assigned(FHintWindow)) then
        FreeAndNil(FHintWindow);
  end;

  AMessage.Result := 0;
end;

procedure TCustomBCEditor.WndProc(var AMessage: TMessage);
begin
  case (AMessage.Msg) of
    WM_LBUTTONDOWN,
    WM_LBUTTONDBLCLK:
      if (not (csDesigning in ComponentState) and not Focused()) then
      begin
        Windows.SetFocus(WindowHandle);
        if (not Focused) then Exit;
      end;
    WM_SETTEXT,
    WM_GETTEXT,
    WM_GETTEXTLENGTH:
      { Handle direct WndProc calls that could happen through VCL-methods like Perform }
      if (HandleAllocated) then
        if (FWindowProducedMessage) then
          FWindowProducedMessage := False
        else
        begin
          FWindowProducedMessage := True;
          with AMessage do
            Result := SendMessageA(WindowHandle, Msg, wParam, LParam);
          Exit;
        end;
  end;

  inherited;
end;

function TCustomBCEditor.WordAtCursor(): string;
begin
  Result := GetWordAt(CaretPos);
end;

function TCustomBCEditor.WordBegin(const ALinesPosition: TBCEditorLinesPosition): TBCEditorLinesPosition;
begin
  Result := ALinesPosition;
  while ((Result.Char - 1 >= 0) and not IsWordBreakChar(FLines.Items[Result.Line].Text[1 + Result.Char - 1])) do
    Dec(Result.Char);
end;

function TCustomBCEditor.WordEnd(): TBCEditorLinesPosition;
begin
  Result := WordEnd(FLines.CaretPosition);
end;

function TCustomBCEditor.WordEnd(const ALinesPosition: TBCEditorLinesPosition): TBCEditorLinesPosition;
begin
  Result := ALinesPosition;
  while ((Result.Char + 1 < Length(FLines.Items[Result.Line].Text)) and not IsWordBreakChar(FLines.Items[Result.Line].Text[1 + Result.Char + 1])) do
    Inc(Result.Char);
end;

{ TBCEditor *******************************************************************}

function TBCEditor.GetLines(): TStrings;
begin
  Result := FLines;
end;

function TBCEditor.IsLinesStored(): Boolean;
begin
  Result := True; // FLines.Text <> '';
end;

procedure TBCEditor.SetLines(const AValue: TStrings);
begin
  FLines.Assign(AValue);
end;

initialization
  GImmEnabled := BOOL(GetSystemMetrics(SM_DBCSENABLED));
  GLineWidth := Round(Screen.PixelsPerInch / USER_DEFAULT_SCREEN_DPI);
  GPadding := Round(Screen.PixelsPerInch / USER_DEFAULT_SCREEN_DPI);

  OleCheck(OleInitialize(nil));
finalization
  OleUninitialize();
end.
