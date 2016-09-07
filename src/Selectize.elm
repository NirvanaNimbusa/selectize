module Selectize
    exposing
        ( init
        , update
        , view
        , selectizeItem
        , selectedItemCodes
        , Model
        , Msg
        , Item
        , HtmlOptions
        , HtmlClasses
        , focused
        , blurred
        )

import Html exposing (..)
import Html.Attributes exposing (value, defaultValue, maxlength, class, classList, id)
import Html.Events exposing (onInput, onBlur, onFocus, onMouseDown, onClick, on)
import Fuzzy
import String
import Json.Decode


-- MODEL


type alias HtmlOptions =
    { instructionsForBlank : String
    , noMatches : String
    , typeForMore : String
    , atMaxLength : String
    , noOptions : String
    , classes : HtmlClasses
    }


type alias HtmlClasses =
    { container : String
    , noOptions : String
    , singleItemContainer : String
    , multiItemContainer : String
    , selectBox : String
    , selectedItems : String
    , fallbackItems : String
    , fallbackItem : String
    , selectedItem : String
    , boxContainer : String
    , boxItems : String
    , boxItem : String
    , boxItemActive : String
    , majorOptionDisplay : String
    , minorOptionDisplay : String
    , info : String
    , infoNoMatches : String
    , inputEditing : String
    }


type alias H =
    HtmlOptions


type alias Item =
    { code : String
    , selectedDisplay : String
    , majorOptionDisplay : String
    , minorOptionDisplay : Maybe String
    , searchWords : List String
    }


type Status
    = Initial
    | Editing
    | Cleared
    | Idle
    | Blurred


selectizeItem : String -> String -> List String -> Item
selectizeItem code display searchWords =
    { code = code
    , selectedDisplay = code
    , majorOptionDisplay = display
    , minorOptionDisplay = Nothing
    , searchWords = searchWords
    }


type alias Items =
    List Item


type alias Model =
    { maxItems : Int
    , boxLength : Int
    , selectedItems : List Item
    , availableItems : List Item
    , boxItems : List Item
    , boxPosition : Int
    , status : Status
    }


pickItems : Items -> List String -> Items
pickItems items codes =
    List.filter (\item -> (List.member item.code codes)) items


defaultItems : Int -> Items -> Items -> Items
defaultItems boxLength availableItems selectedItems =
    List.take boxLength (diffItems availableItems selectedItems)


init : Int -> Int -> List String -> Items -> Model
init maxItems boxLength selectedCodes availableItems =
    let
        selectedItems =
            pickItems availableItems (List.take maxItems selectedCodes)
    in
        { maxItems = maxItems
        , boxLength = boxLength
        , selectedItems = selectedItems
        , availableItems = availableItems
        , boxItems = defaultItems boxLength availableItems selectedItems
        , boxPosition = 0
        , status = Blurred
        }



-- UPDATE


type Msg
    = Input String
    | KeyDown Int
    | KeyUp Int
    | MouseClick Item
    | Blur
    | Focus


focused : Msg -> Bool
focused msg =
    msg == Focus


blurred : Msg -> Bool
blurred msg =
    msg == Blur


selectedItemCodes : Model -> List String
selectedItemCodes model =
    List.map .code model.selectedItems


clean : String -> String
clean s =
    String.trim s
        |> String.toLower


score : String -> Item -> ( Int, Item )
score needle hay =
    let
        cleanNeedle =
            clean needle

        codeScore =
            Fuzzy.match [] [] cleanNeedle (clean hay.code)

        majorScore =
            Fuzzy.match [] [ " " ] cleanNeedle (clean hay.majorOptionDisplay)

        maybeMinorScore =
            Maybe.map
                (\minorOptionDisplay ->
                    (Fuzzy.match [] [ " " ] cleanNeedle (clean minorOptionDisplay))
                )
                hay.minorOptionDisplay

        score =
            case maybeMinorScore of
                Nothing ->
                    min codeScore.score majorScore.score

                Just minorScore ->
                    min codeScore.score majorScore.score
                        |> min minorScore.score
    in
        ( score, hay )


diffItems : Items -> Items -> Items
diffItems a b =
    let
        isEqual itemA itemB =
            itemA.code == itemB.code

        notInB b item =
            (List.any (isEqual item) b)
                |> not
    in
        List.filter (notInB b) a


updateInput : String -> Model -> ( Model, Cmd Msg )
updateInput string model =
    if (String.length string == 0) then
        { model
            | status = Idle
            , boxItems =
                defaultItems model.boxLength model.availableItems (Debug.log "DEBUG1" model.selectedItems)
        }
            ! []
    else
        let
            unselectedItems =
                diffItems model.availableItems (Debug.log "DEBUG2" model.selectedItems)

            boxItems =
                List.map (score string) unselectedItems
                    |> List.sortBy fst
                    |> List.take model.boxLength
                    |> List.filter (((>) 1100) << fst)
                    |> List.map snd
        in
            { model | status = Editing, boxItems = boxItems } ! []


updateSelectedItem : Item -> Model -> ( Model, Cmd Msg )
updateSelectedItem item model =
    let
        selectedItems =
            model.selectedItems ++ [ item ]

        boxItems =
            defaultItems model.boxLength model.availableItems selectedItems
    in
        { model
            | status = Cleared
            , selectedItems = selectedItems
            , boxItems = boxItems
            , boxPosition = 0
        }
            ! []


updateEnterKey : Model -> ( Model, Cmd Msg )
updateEnterKey model =
    let
        maybeItem =
            (List.head << (List.drop model.boxPosition)) model.boxItems
    in
        case maybeItem of
            Nothing ->
                model ! []

            Just item ->
                updateSelectedItem item model


updateBox : Int -> Model -> ( Model, Cmd Msg )
updateBox keyCode model =
    if List.length model.selectedItems == model.maxItems then
        model ! []
    else
        case keyCode of
            -- up
            38 ->
                { model | boxPosition = (max 0 (model.boxPosition - 1)) } ! []

            -- down
            40 ->
                { model
                    | boxPosition =
                        (min ((List.length model.boxItems) - 1)
                            (model.boxPosition + 1)
                        )
                }
                    ! []

            -- enter
            13 ->
                updateEnterKey model

            _ ->
                model ! []


updateBoxInitial : Int -> Model -> ( Model, Cmd Msg )
updateBoxInitial keyCode originalModel =
    let
        ( model, cmd ) =
            updateBox keyCode originalModel
    in
        case keyCode of
            -- backspace
            8 ->
                let
                    allButLast =
                        max 0 ((List.length model.selectedItems) - 1)

                    newSelectedItems =
                        List.take allButLast model.selectedItems

                    boxItems =
                        defaultItems model.boxLength model.availableItems newSelectedItems
                in
                    { model
                        | selectedItems = newSelectedItems
                        , boxItems = boxItems
                    }
                        ! [ cmd ]

            _ ->
                model ! [ cmd ]


updateKey : Int -> Model -> ( Model, Cmd Msg )
updateKey keyCode model =
    case model.status of
        Editing ->
            updateBox keyCode model

        Initial ->
            updateBoxInitial keyCode model

        Idle ->
            updateBoxInitial keyCode model

        Cleared ->
            updateBoxInitial keyCode model

        Blurred ->
            model ! []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Input string ->
            updateInput string model

        KeyDown code ->
            updateKey code model

        KeyUp code ->
            if model.status == Cleared && code == 13 then
                { model | status = Idle } ! []
            else
                model ! []

        MouseClick item ->
            updateSelectedItem item model

        Blur ->
            { model
                | status = Blurred
                , boxPosition = 0
                , boxItems = defaultItems model.boxLength model.availableItems model.selectedItems
            }
                ! []

        Focus ->
            { model
                | status = Initial
                , boxPosition = 0
                , boxItems = defaultItems model.boxLength model.availableItems model.selectedItems
            }
                ! []



-- VIEW


itemView : HtmlOptions -> Bool -> Item -> Html Msg
itemView h isFallback item =
    span
        [ classList
            [ ( h.classes.selectedItem, True )
            , ( h.classes.fallbackItem, isFallback )
            ]
        ]
        [ text item.selectedDisplay ]


fallbackItemsView : HtmlOptions -> List Item -> List Item -> Model -> Html Msg
fallbackItemsView h fallbackItems selectedItems model =
    let
        classes =
            classList
                [ ( h.classes.selectedItems, True )
                , ( h.classes.fallbackItems, List.length selectedItems == 0 )
                ]

        isFallback =
            List.length selectedItems == 0

        items =
            if isFallback then
                fallbackItems
            else
                selectedItems
    in
        span [ classes ] (List.map (itemView h isFallback) items)


itemsView : HtmlOptions -> List Item -> List Item -> Model -> Html Msg
itemsView h fallbackItems selectedItems model =
    case model.status of
        Editing ->
            fallbackItemsView h [] selectedItems model

        Initial ->
            fallbackItemsView h fallbackItems selectedItems model

        Idle ->
            fallbackItemsView h fallbackItems selectedItems model

        Cleared ->
            fallbackItemsView h fallbackItems selectedItems model

        Blurred ->
            fallbackItemsView h fallbackItems selectedItems model


editingBoxView : HtmlOptions -> Model -> Html Msg
editingBoxView h model =
    let
        c =
            h.classes

        boxItemHtml pos item =
            let
                boxItem =
                    case item.minorOptionDisplay of
                        Nothing ->
                            [ span [ class c.majorOptionDisplay ] [ text item.majorOptionDisplay ]
                            ]

                        Just minorOptionDisplay ->
                            [ span [ class c.majorOptionDisplay ] [ text item.majorOptionDisplay ]
                            , span [ class c.minorOptionDisplay ] [ text minorOptionDisplay ]
                            ]
            in
                div
                    [ classList
                        [ ( c.boxItem, True )
                        , ( c.boxItemActive, model.boxPosition == pos )
                        ]
                    , onMouseDown (MouseClick item)
                    ]
                    boxItem
    in
        div [ class c.boxItems ] (List.indexedMap boxItemHtml model.boxItems)


idleBoxView : HtmlOptions -> Model -> Html Msg
idleBoxView h model =
    let
        remainingItems =
            List.length model.availableItems - List.length model.selectedItems

        typeForMore =
            if remainingItems > model.boxLength then
                div [ class h.classes.info ] [ text h.typeForMore ]
            else
                span [] []
    in
        if List.length model.selectedItems == model.maxItems then
            div [ class h.classes.boxContainer ]
                [ div [ class h.classes.info ] [ text h.atMaxLength ] ]
        else
            div [ class h.classes.boxContainer ]
                [ editingBoxView h model
                , typeForMore
                ]


noMatches : HtmlOptions -> Model -> Html Msg
noMatches h model =
    if List.length model.boxItems == 0 then
        div
            [ classList
                [ ( h.classes.info, True )
                , ( h.classes.infoNoMatches, True )
                ]
            ]
            [ text h.noMatches ]
    else
        span [] []


boxView : HtmlOptions -> Model -> Html Msg
boxView h model =
    case model.status of
        Editing ->
            div [ class h.classes.boxContainer ]
                [ editingBoxView h model
                , noMatches h model
                ]

        Initial ->
            idleBoxView h model

        Idle ->
            idleBoxView h model

        Cleared ->
            idleBoxView h model

        Blurred ->
            span [] []


view : HtmlOptions -> List String -> Model -> Html Msg
view h fallbackCodes model =
    if List.length model.availableItems == 0 then
        div [ class h.classes.container ]
            [ div [ class h.classes.noOptions ] [ text h.noOptions ] ]
    else
        let
            fallbackItems =
                pickItems model.availableItems fallbackCodes

            editInput =
                case model.status of
                    Initial ->
                        if (List.length model.selectedItems) < model.maxItems then
                            input [ onBlur Blur, onInput Input ] []
                        else
                            input [ onBlur Blur, onInput Input, maxlength 0 ] []

                    Idle ->
                        if (List.length model.selectedItems) < model.maxItems then
                            input [ onBlur Blur, onInput Input ] []
                        else
                            input [ onBlur Blur, onInput Input, maxlength 0 ] []

                    Editing ->
                        let
                            maxlength' =
                                if List.length model.boxItems == 0 then
                                    0
                                else
                                    524288
                        in
                            input [ maxlength maxlength', onBlur Blur, onInput Input, class h.classes.inputEditing ] []

                    Cleared ->
                        input [ onKeyUp KeyUp, value "", onBlur Blur, onInput Input ] []

                    Blurred ->
                        input [ id "this-id", maxlength 0, onFocus Focus, value "" ] []
        in
            div [ class h.classes.container ]
                [ label
                    [ classList
                        [ ( h.classes.singleItemContainer, model.maxItems == 1 )
                        , ( h.classes.multiItemContainer, model.maxItems > 1 )
                        ]
                    ]
                    [ span [ class h.classes.selectBox, onKeyDown KeyDown ]
                        [ span [] [ itemsView h fallbackItems model.selectedItems model ]
                        , editInput
                        ]
                    , boxView h model
                    ]
                ]


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (Json.Decode.map tagger Html.Events.keyCode)


onKeyUp : (Int -> msg) -> Attribute msg
onKeyUp tagger =
    on "keyup" (Json.Decode.map tagger Html.Events.keyCode)
