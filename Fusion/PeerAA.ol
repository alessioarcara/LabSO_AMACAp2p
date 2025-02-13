include "console.iol"
include "runtime.iol"
include "string_utils.iol"
include "interfacce.iol"
include "ui/swing_ui.iol"
include "EncryptingServiceInterface.iol"
include "DecryptingServiceInterface.iol"
include "KeyGeneratorServiceInterface.iol"
include "ShaAlgorithmServiceInterface.iol"
include "exec.iol"
include "file.iol"
include "time.iol"


outputPort port {
    Protocol: http
    Interfaces: interfacciaB, IGroup
}

outputPort portaStampaConsole {
    Location: "socket://localhost:30000"
    Protocol: http
    Interfaces: teniamoTraccia
}

outputPort KeyGeneratorServiceOutputPort {
  Interfaces: KeyGeneratorServiceInterface
}

outputPort EncryptingServiceOutputPort {
    Interfaces: EncryptingServiceInterface
}

outputPort DecryptingServiceOutputPort {
    Interfaces: DecryptingServiceInterface
}

outputPort ShaAlgorithmServiceOutputPort {
    Interfaces: ShaAlgorithmServiceInterface
}

outputPort JavaSwingConsolePort {
  interfaces: ISwing
}

embedded {
  Java:
    "blend.KeyGeneratorService" in KeyGeneratorServiceOutputPort,
    "blend.EncryptingService" in EncryptingServiceOutputPort,
    "blend.DecryptingService" in DecryptingServiceOutputPort,
    "blend.ShaAlgorithmService" in ShaAlgorithmServiceOutputPort,
    "blend.JavaSwingConsole" in JavaSwingConsolePort
}

constants {
    limiteLunghezzaMessaggio = 63
}

init {
    //RICERCA PRIMA PORTA LIBERA TRA 10001 E 10101 
    condition = true
    portNum = 10001
    while( condition && portNum < 10102 ) {
        scope( e ){
            install( RuntimeException  => {
                portNum = portNum + 1
            })
            with( emb ) {
                .filepath = "-C LOCATION=\"" + "socket://localhost:" + portNum + "\" PeerBB.ol"
                .type = "Jolie"
            };
            loadEmbeddedService@Runtime( emb )()

            num_port = portNum //Assegnazione numero di porta generato 
            condition = false //Settaggio variabile bool condition
        }
    }
    
    //Controllo di aver trovato una porta libera
    if ( condition ) {
        install ( NoPortAvaible => println@Console( "\n\nTutte le porte della rete sono occupate.\n\n" )() )
        throw( NoPortAvaible )
    }
    port.location = "socket://localhost:" + num_port //Settaggio porta
    setPort@port( num_port )()  

    //Gestione errore dovuto al button "annulla" nelle SwingUI
    install( TypeMismatch => {
        trim@StringUtils( user.name )( responseTrim ) //Trim della stringa passata come request
        if( is_defined( user.name ) && !( responseTrim instanceof void ) ) {
            scope( exceptionConsole ) {
                install( IOException => println@Console("Errore, console non disponibile!")() )
                press@portaStampaConsole( user.name + " si è arrestato/a inaspettatamente!" )()
            }
            
        } else {
            scope( exceptionConsole ) {
                install( IOException => println@Console("Errore, console non disponibile!")() )
                press@portaStampaConsole( "Un utente si è arrestato inaspettatamente!" )()
            }
            
        }
    })
}

//CHAT PRIVATA
define startChat {
    //START CHATTING
    scope( e ) {

        //Gestione errore se l'utente abbandona la rete
        install( IOException => println@Console( "L'utente è andato offline.")() )

        mesg.username = user.name 
        port.location = "socket://localhost:" + dest_port

        //Invio richiesta di chat al destinatario
        chatRequest@port( user.name )( enter ) //enter variabile booleana

        if ( enter ) {
            
            with( richiesta ) {
                .filename = "BackupChat/DATABASE_" + user.name + ".txt"
                .content = "\nINIZIO A MANDARE MESSAGGI A " + dest + "\n"
                .append = 1
            }
            writeFile@File( richiesta )()
                
            //Recupero chiavi pubbliche del destinatario
            richiestaChiavi@port()( chiaviPubblicheDestinatario )
            request.publickey1 = chiaviPubblicheDestinatario.publickey1
            request.pub_priv_key = chiaviPubblicheDestinatario.publickey2
            request.cripto_bit = 1

            scope( exceptionConsole ) {
                install( IOException => println@Console("Errore, console non disponibile!")() )
                press@portaStampaConsole( user.name + " ha iniziato la comunicazione con " + dest )()
            }
            
            responseMessage = ""
            
            while( responseMessage != "EXIT" ) {
                scope( exception ) {
                    install( StringIndexOutOfBoundsException => {
                        scope( exceptionConsole ) {
                            install( IOException => println@Console("Errore, console non disponibile!")() )
                            press@portaStampaConsole( user.name + " ha inserito un messaggio troppo lungo!" )() 
                        }
                    })
                    showInputDialog@SwingUI( user.name + "\nInserisci messaggio per " + dest + " ( 'EXIT' per uscire ):" )( responseMessage )         

                    getCurrentDateTime@Time()(Data) //Generazione data e ora 

                    //Registrazione lunghezza messaggio 
                    length@StringUtils( responseMessage )( lunghezzaMessaggio )
                    
                    if ( responseMessage == "EXIT" ) {
                        scope( exceptionConsole ) {
                            install( IOException => println@Console("Errore, console non disponibile!")() )
                            press@portaStampaConsole( user.name + " ha abbandonato la comunicazione con " + dest )() 
                        }
                        
                    } else {
                        //CIFRATURA RSA CON PADDING
                        //Passo il plaintext al javaservice
                        if( lunghezzaMessaggio < limiteLunghezzaMessaggio ){ //Controllo lunghezza messaggio 
                            //Scrittura su file
                            with( richiesta ) {
                                .filename = "BackupChat/DATABASE_" + user.name + ".txt"
                                .content = Data + "\t" + user.name + ": " + responseMessage + " \n"
                                .append = 1
                            }
                            writeFile@File( richiesta )() //Scrittura su file 
                            //stampa messaggio in console
                            println@Console( Data + "\t" + user.name + ": " + responseMessage )(  )
                            //codifica e spedizione messaggio
                            request.message = responseMessage
                            Codifica_RSA@EncryptingServiceOutputPort( request )( response )
                            mesg.text = response.message

                            sendString@port( mesg )( response ) 
                        } else {
                            scope( exceptionConsole ) {
                                install( IOException => println@Console( "Errore, console non disponibile!" )() )
                                press@portaStampaConsole( "Messaggio troppo lungo!" )()
                            }
                        }
                    }
                }
            }
        } else {
            println@Console( "L'utente ha rifiutato la tua richiesta di chattare." )()
            scope( exceptionConsole ) {
                install( IOException => println@Console("Errore, console non disponibile!")() )
                press@portaStampaConsole( dest + " ha rifiutato la conversazione con " + user.name )() 
            }
        }
    }
}

define broadcastMsg {
    for( i = 10001, i < 10101, i++ ) {
        scope( e ) {
            install( IOException => i = i )
            if( i != user.port ) {
                port.location = "socket://localhost:" + i
                broadcast@port( user.port )
            }
        }
    }
}

//CHAT PUBBLICA
define startGroupChat {
    
    //inizializzazione persistenza
    with( richiesta ) {
        .filename = "BackupChat/DATABASE_" + user.name + ".txt"
        .content = "\nINIZIO COMUNICAZIONE CON GRUPPO " + group.name + "\n"
        .append = 1
    }
    writeFile@File( richiesta )()
    
    
    //START CHATTING
    scope( e ) {

        //Gestione errore nel momento in cui host va online
        install( IOException => {
            println@Console( "L'host del gruppo è andato offline.")()
        })

        msg.username = user.name 
        scope( exceptionConsole ) {
            install( IOException => println@Console("Errore, console non disponibile!")() )
            press@portaStampaConsole( user.name + " ha iniziato la comunicazione con il gruppo " + group.name + "! " + "( " + group.port + " )"  )()
        }
        
        
        //Settaggio messaggio per entrata nel while
        responseMessage = ""
        
        while( responseMessage != "EXIT" ) {
            scope( exception ) {
                showInputDialog@SwingUI( user.name + "\nInserisci messaggio per il gruppo " + group.name + " ( 'EXIT' per uscire ):" )( responseMessage )         

                if ( responseMessage == "EXIT" ) {
                    exitGroup@port( user )()
                    scope( exceptionConsole ) {
                        install( IOException => println@Console("Errore, console non disponibile!")() )
                        press@portaStampaConsole( user.name + " ha abbandonato il gruppo " + group.name )()
                    }
                    
                } else {
                    //CIFRATURA CON ALGORITMO SHA2
                    //Passo il plaintext al javaservice "ShaAlgorithmService", che mi ritorna l'hash del messaggio in chiaro
                    hash.message = responseMessage
                    ShaPreprocessingMessage@ShaAlgorithmServiceOutputPort ( hash ) ( hash_response )

                    port.location = "socket://localhost:" + user.port
                    richiestaProprieChiavi@port()( chiaviPersonaliResponse )

                    //Passo l'hash del messaggio al javaservice "EncryptingService" che ne fa la codifica con la chiave privata --> K-( H(m) )
                    codifica.message = hash_response.message
                    codifica.publickey1 = chiaviPersonaliResponse.publickey1
                    codifica.pub_priv_key = chiaviPersonaliResponse.privatekey
                    codifica.cripto_bit = 0

                    Codifica_RSA@EncryptingServiceOutputPort( codifica )( codifica_response )
                    
                    //Invio al peer ricevente il messaggio in chiaro ed il criptato con la chiave privata dell'hash del messaggio
                    msg.text = responseMessage                          //messaggio in chiaro ( plaintext )
                    msg.message = codifica_response.message             //messaggio codificato ( K^-( H(m) )
                    msg.publickey1 = chiaviPersonaliResponse.publickey1 //invio prima componente chiave pubblica (n)
                    msg.publickey2 = chiaviPersonaliResponse.publickey2 //invio seconda componente chiave pubblica (e)

                    port.location = "socket://localhost:" + group.port
                    sendMessage@port( msg )
                }
            }
        }
    }
}

main {
    //Invio broadcast
    user.port = num_port

    broadcastMsg

    //Iscrizione nella rete
    port.location = "socket://localhost:" + user.port
    login@port(user.port)(user.name)

    searchPeer@port( "undefined" )( response )

    //Gestione nel caso in cui ci siano peer con un username ancora non definito
    while ( response != 0 ) {
        scope(e) {
            install( IOException => a=0 )
            port.location = "socket://localhost:" + response
            sendUsername@port(user)
        } 
        port.location = "socket://localhost:" + user.port
        searchPeer@port( "undefined" )( response )
    }

    //Stampo su monitor il peer aggiunto alla rete
    scope( exceptionConsole ) {
        install( IOException => println@Console("Errore, console non disponibile!")() )
        press@portaStampaConsole( user.name + " si è unito/a alla rete! " + "( " + num_port + " )" )()
    }

    //Creazione file persistenza
    scope(exceptionFile){
        install( IOException => exec@Exec("NUL> BackupChat/DATABASE_" + user.name + ".txt")() )
        exec@Exec( "touch BackupChat/DATABASE_" + user.name + ".txt" )()
    }
    
    //GENERAZIONE CHIAVI
    port.location = "socket://localhost:" + user.port //Nuovo settaggio porta personale
    generateKey@port()()

    //WAIT FOR INSTRUCTION
    status = true
    while ( status ) {

        aperturaMenu@JavaSwingConsolePort( "User: " + user.name + "\nSeleziona istruzione: " )( instruction )

        port.location = "socket://localhost:" + user.port

        if ( instruction == 2 ) { //Permette al peer di uscire dalla rete 
            status = false
            
            scope( exceptionConsole ) {
                install( IOException => println@Console("Errore, console non disponibile!")() )
                press@portaStampaConsole( user.name + " ha abbandonato la rete" )()
            }
        } 
        else 
            if ( instruction == 0 ) { //Permette al peer di iniziare una chat privata 

                showInputDialog@SwingUI( user.name + "\nInserisci username da contattare: " )( dest )

                //Restituisce il numero di porta da contattare del destinatario ( 0 se inesistente ) 
                searchPeer@port( dest )( dest_port )
            
                if ( dest_port == 0 ) {
                    println@Console( "L'username ricercato non esiste." )(  )
                } else {
                    startChat
                }
        }
        else if ( instruction == 3 ) {

            //RICERCA PRIMA PORTA DISPONIBILE 
            condition = true
            portNum = 10001
            while( condition ) {
                scope( e ){
                    install( RuntimeException  => {
                        portNum = portNum + 1
                    })
                    with( emb ) {
                        .filepath = "-C LOCATION=\"" + "socket://localhost:" + portNum + "\" PeerGroup.ol"
                        .type = "Jolie"
                    };
                    loadEmbeddedService@Runtime( emb )()
                    group.port = portNum
                    condition = false
                }
            }

            //Inserisci nome gruppo da creare e controllo
            condition = true
            while(condition) {
                showInputDialog@SwingUI( user.name + "\nInserisci nome gruppo da creare" )( groupName )

                //Settaggio gruppo ad UpperCase
                toUpperCase@StringUtils( groupName )( group.name )

                port.location = "socket://localhost:" + user.port

                //Verifica che non ci sia un gruppo con lo stesso nome
                searchPeer@port( group.name )( response )

                if ( response == 0 ) {
                    condition = false
                } else {
                    println@Console( "Impossibile creare un gruppo con questo nome." )()
                    scope( exceptionConsole ) {
                        install( IOException => println@Console("Errore, console non disponibile!")() )
                        press@portaStampaConsole( user.name + " ha provato a creare il gruppo " + group.name + " già esistente!" )()
                    }
                }
            }
            port.location = "socket://localhost:" + group.port
            group.host = user.port
            setGroup@port( group )()
            
            //Messaggio broadcast per avvisare gli altri peer della creazione del gruppo
            for( i = 10001, i < 10101, i++ ) {
                scope( e ) {
                    install( IOException => i = i)
                    if( i != group.port ) {
                        port.location = "socket://localhost:" + i
                        broadcast@port( group.port )
                    }
                }
            }

            //Inizio chat del gruppo
            startGroupChat

        } 
        else if ( instruction == 1 ) {
            scope(e) {
                install( IOException => {
                    println@Console("L'host del gruppo è andato offline.")()
                    press@portaStampaConsole( user.name + " ha ricercato un gruppo " + group.name + " inesistente!" )() 
                })

                showInputDialog@SwingUI( user.name + "\nInserisci nome del gruppo: " )( responseContact )
                group.name = responseContact

                //Ricerca porta di gruppo per la comunicazione pubblica
                searchPeer@port( group.name )( group.port )
            
                if ( group.port == 0 ) {
                    println@Console( "Il gruppo ricercato non esiste." )()
                    scope( exceptionConsole ) {
                        install( IOException => println@Console("Errore, console non disponibile!")() )
                        press@portaStampaConsole( user.name + " ha ricercato un gruppo " + group.name + " inesistente!")()
                    }
                } else {
                    port.location = "socket://localhost:" + group.port
                    enterGroup@port( user )() 
                    println@Console( "\nBenvenuto nel gruppo " + group.name + "!\n" )()

                    //Inizio la comunicazione con il gruppo
                    startGroupChat
                }
            }

        }
        else if( instruction == -1 ) {
            status = false
            scope( exceptionConsole ) {
                install( IOException => println@Console("Errore, console non disponibile!")() )
                press@portaStampaConsole( user.name + " ha abbandonato la rete" )()
            }
        } else {
            println@Console("\nIstruzione sconosciuta.")()
        }
    }   
}