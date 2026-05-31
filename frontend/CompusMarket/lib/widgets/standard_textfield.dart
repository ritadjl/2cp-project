import 'package:flutter/material.dart';

class StandardTextfield extends StatefulWidget {
  final String title;
  final String hint;
  final bool isPassword;
  final bool isEmail;
  final bool isPhone;
  final TextEditingController? controller;
  final bool isError;
  final Color? fillColor;
  final bool hasShadow;
  final int maxLines;

  const StandardTextfield({
    super.key,
    required this.title,
    required this.hint,
    this.isPassword = false,
    this.isEmail = false,
    this.isPhone = false,
    this.controller,
    this.isError = false,
    this.fillColor,
    this.hasShadow = false,
    this.maxLines = 1,
  });

  @override
  // ignore: library_private_types_in_public_api
  _StandardTextfieldState createState() => _StandardTextfieldState();
}

class _StandardTextfieldState extends State<StandardTextfield> {
  bool visibility = true;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.037,
          ),
        ),

        SizedBox(height: screenHeight * 0.0074),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(screenWidth * 0.035),
            boxShadow: widget.hasShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: widget.isPassword ? visibility : false,
            autofillHints: const [],
            keyboardType: widget.isEmail
                ? TextInputType.emailAddress
                : widget.isPhone
                ? TextInputType.phone
                : TextInputType.text,
            autocorrect: widget.isEmail ? false : true,
            enableSuggestions: widget.isEmail ? false : true,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        visibility ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => visibility = !visibility),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.035),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.035),
                borderSide: widget.isError
                    ? BorderSide(color: Colors.red, width: screenWidth * 0.0047)
                    : BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.035),
                borderSide: widget.isError
                    ? BorderSide(color: Colors.red, width: screenWidth * 0.0047)
                    : BorderSide(
                        color: Colors.blue,
                        width: screenWidth * 0.0047,
                      ),
              ),
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xffa4abb8),
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
              ),
              fillColor:
                  widget.fillColor ??
                  Color(0xffeceff3), // ← uses passed color or default
              filled: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: screenWidth * 0.047,
                horizontal: screenHeight * 0.01,
              ),
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.021),
      ],
    );
  }
}
