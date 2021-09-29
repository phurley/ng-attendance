module Main exposing (main)

import Browser exposing (UrlRequest)
import Browser.Navigation as Navigation
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode exposing (Decoder, field, int, list, map2, string)
import Json.Encode as Encode
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
    , name : String
    , email : String
    , student_id : String
    , students : List Student
    }


type alias Student =
    { name : String, id : Int }


type Mode
    = Welcome
    | Login
    | Status
    | Register
    | CheckIn


init : String -> ( Model, Cmd Msg )
init url =
    ( { mode = Welcome, url = url, name = "", email = "", student_id = "", students = [] }
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
    | GotoCheckin
    | CompleteRegistration
    | GotStudents (Result Http.Error (List Student))
    | GotRegistration (Result Http.Error (List Student))
    | UpdateName String
    | UpdateEmail String
    | UpdateStudentId String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotoLogin ->
            ( { model | mode = Login }, Cmd.none )

        GotoStatus ->
            ( { model | mode = Status }, Cmd.none )

        GotoWelcome ->
            ( { model | mode = Welcome }, Cmd.none )

        GotoCheckin ->
            ( { model | mode = Register }, Cmd.none )

        GotoRegister ->
            ( { model | mode = Register }, Cmd.none )

        CompleteRegistration ->
            ( { model | mode = Welcome }
            , Http.post
                { url = "http://localhost:1234/register"
                , body =
                    Http.jsonBody
                        (Encode.object
                            [ ( "name", Encode.string model.name )
                            , ( "email", Encode.string model.email )
                            , ( "student_id", Encode.string model.student_id )
                            ]
                        )
                , expect = Http.expectJson GotRegistration (Json.Decode.list studentDecoder)
                }
            )

        GotStudents result ->
            case result of
                Ok students ->
                    ( { model | students = students }, Cmd.none )

                Err _ ->
                    Debug.log "Http Error"
                        ( model, Cmd.none )

        GotRegistration result ->
            case result of
                Ok students ->
                    ( { model | mode = CheckIn, students = students }, Cmd.none )

                Err _ ->
                    Debug.log "Http Error"
                        ( model, Cmd.none )

        UpdateName n ->
            ( { model | name = n }, Cmd.none )

        UpdateEmail e ->
            ( { model | email = e }, Cmd.none )

        UpdateStudentId i ->
            ( { model | student_id = i }, Cmd.none )


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

        CheckIn ->
            viewCheckIn model


viewWelcome model =
    div []
        [ mkButton "Login" GotoLogin
        , text " "
        , mkButton "Register" GotoRegister
        ]


viewStatus model =
    div [] [ mkButton "Welcome" GotoWelcome ]


viewLogin model =
    div []
        [ mkCombo "Student" model.students
        , mkButton "Status" GotoStatus
        , h2 [] [ text "Hi Pat" ]
        ]


viewRegister model =
    div []
        [ mkInput "Name" UpdateName
        , mkInput "Student Id" UpdateStudentId
        , mkInput "Email" UpdateEmail
        , mkButton "Register" CompleteRegistration
        ]


viewCheckIn model =
    div []
        [ mkInput "Name" UpdateName
        , mkButton "Check In" GotoStatus
        ]


mkButton label action =
    Html.button [ onClick action, class "button-primary" ] [ text label ]


student2Option stud =
    Html.option [ value stud.name ] []


mkCombo label dlist =
    let
        nam =
            String.toLower (String.replace " " "_" label)

        lst =
            nam ++ "_list"
    in
    Html.span []
        [ Html.label [ for nam ] [ text label ]
        , Html.input [ id nam, class "u-full-width", name nam, required True, Html.Attributes.list lst ] []
        , Html.datalist [ id lst ] (List.map student2Option dlist)
        ]



-- mkInput : String -> Html msg


mkInput label cmd =
    let
        nam =
            String.toLower (String.replace " " "_" label)
    in
    Html.span []
        [ Html.label [ for nam ] [ text label ]
        , Html.input [ id nam, class "u-full-width", name nam, required True, onInput cmd ] []
        ]
