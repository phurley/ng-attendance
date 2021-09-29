module Main exposing (main)

import Browser exposing (UrlRequest)
import Browser.Navigation as Navigation
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http
import Json.Decode exposing (Decoder, field, int, list, map2, string)
import Url exposing (Url)
import Url.Parser as UrlParser exposing ((</>), Parser, s, top)


main =
    Browser.element
        { view = view
        , init = init
        , update = update
        , subscriptions = always Sub.none
        }


type alias Model =
    { mode : Mode
    , url : String
    , students : List Student
    }


type alias Student =
    { name : String, id : Int }


type Mode
    = Welcome
    | Login
    | Status
    | Register
--    | CheckIn


init : String -> ( Model, Cmd Msg )
init url =
    ( { mode = Welcome, url = url, students = [] }
    , Http.get
        { url = "http://localhost:1234/students"
        , expect = Http.expectJson GotStudents (Json.Decode.list studentDecoder)
        }
    )


studentDecoder : Decoder Student
studentDecoder =
    map2 Student
        (field "name" string)
        (field "id" int)


type Msg
    = GotoLogin
    | GotoStatus
    | GotoWelcome
    | GotoRegister
    | GotStudents (Result Http.Error (List Student))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotoLogin ->
            ( { model | mode = Login }, Cmd.none )

        GotoStatus ->
            ( { model | mode = Status }, Cmd.none )

        GotoWelcome ->
            ( { model | mode = Welcome }, Cmd.none )

        GotoRegister ->
            ( { model | mode = Register }, Cmd.none )

        GotStudents result ->
            case result of
                Ok students ->
                    ( { model | students = students }, Cmd.none )

                Err _ ->
                    Debug.log "Http Error"
                        ( model, Cmd.none )


view : Model -> Html Msg
view model =
    case model.mode of
        Welcome ->
            viewWelcome model

        Login ->
            viewLogin model

        Status ->
            viewStatus model

        Register ->
            viewRegister model


viewWelcome model =
    div []
        [ mkButton "Login" GotoLogin
        , br [] []
        , mkButton "Register" GotoRegister
        ]


viewStatus model =
    div [] [ mkButton "Welcome" GotoWelcome ]


viewLogin model =
    div [] 
        [  mkCombo "Student" model.students 
           , mkButton "Status" GotoStatus 
        ]


viewRegister model =
    div []
        [ mkInput "First Name"
        , mkInput "Last Name"
        , mkInput "Student Id"
        , mkButton "Register" GotoLogin
        ]


viewCheckIn model =
    div []
        [ mkInput "Name"
        , mkButton "Check In" GotoWelcome
        ]


mkButton label action =
    Html.button [ onClick action, class "button-primary" ] [ text label ]


mkInput : String -> Html msg
mkInput label =
    mkField label (String.toLower (String.replace " " "_" label))


mkField : String -> String -> Html msg
mkField label nam =
    Html.span []
        [ Html.label [ for nam ] [ text label ]
        , Html.input [ id nam, class "u-full-width", name nam, required True ] []
        ]
