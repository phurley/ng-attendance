module Main exposing (main)

import Browser exposing (UrlRequest)
import Browser.Navigation as Navigation
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode exposing (Decoder, field, int, list, map2, string)
import Json.Encode as Encode
import Time


main =
    Browser.element
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { mode : Mode
    , url : String
    , name : String
    , email : String
    , student_id : String
    , flash : String
    , students : List Student
    , checkedIn : List String
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
    ( { mode = Welcome, url = url, name = "", email = "", student_id = "", flash = "", students = [], checkedIn = [] }
    , Http.get
        { url = "/api/students"
        , expect = Http.expectJson GotStudents (Json.Decode.list studentDecoder)
        }
    )


studentDecoder : Decoder Student
studentDecoder =
    map2 Student
        (field "name" string)
        (field "id" int)


nameDecoder : Decoder (List String)
nameDecoder =
    Json.Decode.list string


type Msg
    = GotoLogin
    | GotoStatus
    | GotoWelcome
    | GotoRegister
    | GotoCheckin
    | CompleteRegistration
    | CompleteCheckin
    | CompleteLogin
    | GotStudents (Result Http.Error (List Student))
    | GotRegistration (Result Http.Error (List Student))
    | GotCheckin (Result Http.Error ())
    | GotLogin (Result Http.Error (List String))
    | GotStatusUpdate (Result Http.Error (List String))
    | UpdateName String
    | UpdateEmail String
    | UpdateStudentId String
    | Tick Time.Posix
    | DoNothing


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every 1000 Tick


findId model =
    let
        name =
            model.name

        students =
            model.students

        found =
            List.head (List.filter (\s -> s.name == name) students)
    in
    case found of
        Just student ->
            student.id

        Nothing ->
            -1


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
            ( { model | mode = CheckIn }, Cmd.none )

        GotoRegister ->
            ( { model | mode = Register }, Cmd.none )

        CompleteCheckin ->
            ( { model | flash = "Processing" }
            , Http.request
                { method = "POST"
                , expect = Http.expectJson GotLogin nameDecoder
                , headers = [ Http.header "User" (String.fromInt (findId model)) ]
                , url = "/api/checkin"
                , body = Http.emptyBody
                , timeout = Nothing
                , tracker = Nothing
                }
            )

        CompleteLogin ->
            ( { model | flash = "Processing" }
            , Http.request
                { method = "POST"
                , expect = Http.expectWhatever GotCheckin
                , headers = [ Http.header "User" (String.fromInt (findId model)) ]
                , url = "/api/checkin"
                , body = Http.emptyBody
                , timeout = Nothing
                , tracker = Nothing
                }
            )

        CompleteRegistration ->
            if String.isEmpty model.name then
                ( { model | flash = "Name cannot be blank", mode = Register }, Cmd.none )

            else if String.isEmpty model.email then
                ( { model | flash = "Email cannot be blank", mode = Register }, Cmd.none )

            else
                ( { model | flash = "Processing" }
                , Http.post
                    { url = "/api/register"
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

        GotLogin result ->
            case result of
                Ok checkedIn ->
                    ( { model | mode = Status, checkedIn = checkedIn }, Cmd.none )

                Err _ ->
                    ( { model | flash = "Unable to check, please verify your name" }, Cmd.none )

        GotStudents result ->
            case result of
                Ok students ->
                    ( { model | students = students }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        GotRegistration result ->
            case result of
                Ok students ->
                    ( { model | mode = CheckIn, students = students, flash = "Registered" }, Cmd.none )

                Err m ->
                    ( { model | flash = "Unable to add new member, probably already registerd" }, Cmd.none )

        GotCheckin result ->
            case result of
                Ok _ ->
                    ( { model | mode = Status, flash = "Checked In" }, Cmd.none )

                Err m ->
                    ( { model | flash = "Something failed checking you in -- sorry." }, Cmd.none )

        GotStatusUpdate result ->
            case result of
                Ok students ->
                    ( { model | mode = Status, checkedIn = students, flash = "" }, Cmd.none )

                Err m ->
                    ( { model | flash = "Something failed during status update -- sorry." }, Cmd.none )

        UpdateName n ->
            ( { model | flash = "", name = String.trimLeft n }, Cmd.none )

        UpdateEmail e ->
            ( { model | flash = "", email = String.trim e }, Cmd.none )

        UpdateStudentId i ->
            ( { model | flash = "", student_id = String.trim i }, Cmd.none )

        Tick _ ->
            if model.mode == Status then
                ( { model | flash = "" }
                , Http.request
                    { method = "GET"
                    , expect = Http.expectJson GotStatusUpdate nameDecoder
                    , headers = []
                    , url = "/api/today"
                    , body = Http.emptyBody
                    , timeout = Nothing
                    , tracker = Nothing
                    }
                )

            else
                ( { model | flash = "" }, Cmd.none )

        DoNothing ->
            ( { model | flash = "" }, Cmd.none )


view : Model -> Html Msg
view model =
    case model.mode of
        Welcome ->
            layout viewWelcome model

        Login ->
            layout viewLogin model

        Status ->
            layout viewStatus model

        Register ->
            layout viewRegister model

        CheckIn ->
            layout viewCheckIn model


layout v m =
    div []
        [ if not (String.isEmpty m.flash) then
            div [ class "row flash" ]
                [ div [ class "u-full-width" ] [ text m.flash ]
                ]

          else
            div [] []
        , div [] [ v m ]
        ]


viewWelcome model =
    div []
        [ mkButton "CheckIn" GotoCheckin
        , text " "
        , mkButton "Register" GotoRegister
        , text " "
        , mkButton "Status" GotoStatus
        ]


viewStatus model =
    div []
        [ h2 [] [ text "Currently checked in students" ]
        , ul [] (List.map (\name -> li [] [ text name ]) model.checkedIn)
        ]


viewLogin model =
    Html.form [ onSubmit CompleteLogin ]
        [ mkCombo "Student" model.students model.name UpdateName
        , mkInput "Student Id" model.student_id UpdateStudentId
        , mkButton "Login" DoNothing
        ]


viewRegister model =
    Html.form [ onSubmit CompleteRegistration ]
        [ mkInput "Name" model.name UpdateName
        , mkInput "Student Id" model.student_id UpdateStudentId
        , mkInput "Email" model.email UpdateEmail
        , mkButton "Register" DoNothing
        , text " "
        , mkButton "Login" GotoLogin
        ]


viewCheckIn model =
    Html.form [ onSubmit CompleteCheckin ]
        [ mkCombo "Student" model.students model.name UpdateName
        , mkButton "Check In" DoNothing
        ]


mkButton label action =
    Html.button [ onClick action, class "button-primary" ] [ text label ]


student2Option stud =
    Html.option [ value stud.name ] []


mkCombo label dlist val cmd =
    let
        nam =
            String.toLower (String.replace " " "_" label)

        lst =
            nam ++ "_list"
    in
    Html.span []
        [ Html.label [ for nam ] [ text label ]
        , Html.input [ id nam, class "u-full-width", name nam, required True, Html.Attributes.list lst, value val, onInput cmd ] []
        , Html.datalist [ id lst ] (List.map student2Option dlist)
        ]



-- mkInput : String -> Html msg


mkInput label val cmd =
    let
        nam =
            String.toLower (String.replace " " "_" label)
    in
    Html.span []
        [ Html.label [ for nam ] [ text label ]
        , Html.input [ id nam, class "u-full-width", name nam, value val, onInput cmd ] []
        ]
