module Selectize
    exposing
        ( init
        , update
        , view
        , selectizeItem
        , Model
        , Msg
        , Item
        , keyDown
        )

import Html exposing (..)
import Html.Attributes exposing (value, defaultValue, readonly)
import Html.Events exposing (onInput)
import Fuzzy
import String


-- MODEL


type alias Item =
    { code : String
    , display : String
    , searchWords : List String
    }


type Status
    = Initial
    | Editing
    | Cleared


selectizeItem : String -> String -> List String -> Item
selectizeItem code display searchWords =
    { code = code
    , display = display
    , searchWords = searchWords
    }


type alias Items =
    List Item


type alias Model =
    { selectedItems : Items
    , availableItems : Items
    , boxItems : Items
    , boxLength : Int
    , boxPosition : Int
    , boxShow : Bool
    , maxItems : Int
    , status : Status
    }


init : Int -> Items -> Model
init maxItems availableItems =
    { availableItems = availableItems
    , selectedItems = []
    , boxItems = []
    , boxLength = 5
    , boxPosition = 0
    , boxShow = False
    , maxItems = maxItems
    , status = Initial
    }



-- UPDATE


type Msg
    = Input String
    | KeyDown Int
    | SelectedItems (List Item)


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

        displayScore =
            Fuzzy.match [] [ " " ] cleanNeedle (clean hay.display)
    in
        ( min codeScore.score displayScore.score, hay )


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
    if (String.length string < 2) then
        { model | status = Editing, boxItems = [] } ! []
    else
        let
            unselectedItems =
                diffItems model.availableItems model.selectedItems

            boxItems =
                List.map (score string) unselectedItems
                    |> List.sortBy fst
                    |> List.take model.boxLength
                    |> List.filter (((>) 1100) << fst)
                    |> List.map snd
        in
            { model | status = Editing, boxItems = boxItems } ! []


updateKey : Int -> Model -> ( Model, Cmd Msg )
updateKey keyCode model =
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
            let
                maybeItem =
                    (List.head << (List.drop model.boxPosition)) model.boxItems
            in
                case maybeItem of
                    Nothing ->
                        model ! []

                    Just item ->
                        { model
                            | status = Cleared
                            , selectedItems = model.selectedItems ++ [ item ]
                            , boxPosition = 0
                        }
                            ! []

        -- backspace
        8 ->
            if model.status == Initial then
                let
                    allButLast =
                        max 0 ((List.length model.selectedItems) - 1)

                    newSelectedItems =
                        List.take allButLast model.selectedItems
                in
                    { model | selectedItems = newSelectedItems } ! []
            else
                model ! []

        _ ->
            if model.status == Cleared then
                { model | status = Initial } ! []
            else
                model ! []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Input string ->
            updateInput string model

        KeyDown code ->
            updateKey code model

        SelectedItems items ->
            { model
                | selectedItems = items
                , boxItems = []
                , boxPosition = 0
                , status = Cleared
            }
                ! []



-- VIEW


itemView : Item -> Html Msg
itemView item =
    div [] [ text item.display ]


itemsView : List Item -> Html Msg
itemsView items =
    div [] (List.map itemView items)


boxView : Model -> Html Msg
boxView model =
    let
        boxItemHtml pos item =
            if model.boxPosition == pos then
                div [] [ text ("* " ++ item.display) ]
            else
                div [] [ text item.display ]
    in
        if model.status == Editing then
            div [] (List.indexedMap boxItemHtml model.boxItems)
        else
            div [] []


view : Model -> Html Msg
view model =
    let
        editInput =
            case model.status of
                Initial ->
                    if (List.length model.selectedItems) < model.maxItems then
                        input [ onInput Input ] []
                    else
                        input [ readonly True ] []

                Editing ->
                    input [ onInput Input ] []

                Cleared ->
                    input [ value "", onInput Input ] []
    in
        div []
            [ div []
                [ div [] [ itemsView model.selectedItems ]
                , editInput
                ]
            , boxView model
            ]


keyDown : Int -> Msg
keyDown code =
    KeyDown code
