<?php



// Cyberpower678 May 2017

// The MIT License (MIT)
//
// Copyright (c) 2017 by User:Cyberpower678 (at en.wikipedia.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


//

// So this is the other script to call. This will serve you for both testing and actually usage. When the /identify request is successful, it will return a payload.

// That payload has numerous elements to decode and validate.

// And requires your Consumer secret to validate. The tool API passes back the payload as well since it can't do the validation without the consumer secret, and that would be plain reckless to ask for.

// To decode the payload, call in the CLI or from your app

//   php MWOAuthDecodePayload.php <consumer secret> <payload>

// If successful, it will echo back a JSON with your MW account details. If it fails, it will echo back an error message instead.

// This also isn't tested since I copied it from my OAuth engine.



if( !isset( $argv[1] ) || !isset( $argv[2] ) ) die( "FAIL" );



define( 'CONSUMERSECRET', $argv[1] );



// There are three fields in the response

$fields = explode( '.', $argv[2] );

if( count( $fields ) !== 3 ) {

#	$error = 'Invalid identify response: ' . htmlspecialchars( $data );

	$error = 'Invalid identify response: ';



	goto loginerror;

}



// Validate the header. MWOAuth always returns alg "HS256".

$header = base64_decode( strtr( $fields[0], '-_', '+/' ), true );

if( $header !== false ) {

	$header = json_decode( $header );

}

if( !is_object( $header ) || $header->typ !== 'JWT' || $header->alg !== 'HS256' ) {

	$error = 'Invalid header in identify response: ' . htmlspecialchars( $data );



	goto loginerror;

}



// Verify the signature

$sig = base64_decode( strtr( $fields[2], '-_', '+/' ), true );

$check = hash_hmac( 'sha256', $fields[0] . '.' . $fields[1], CONSUMERSECRET, true );

if( $sig !== $check ) {

//	$error = 'JWT signature validation failed: ' . htmlspecialchars( $data );

	$error = 'JWT signature validation failed: ';



	goto loginerror;

}



// Decode the payload

$payload = base64_decode( strtr( $fields[1], '-_', '+/' ), true );

if( $payload !== false ) {

	$payload = json_decode( $payload );

}

if( !is_object( $payload ) ) {

	$error = 'Invalid payload in identify response: ' . htmlspecialchars( $data );



	goto loginerror;

}



die( json_encode( $payload ) );



loginerror:

die( $error );


