<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, javax.servlet.http.*, javax.servlet.*, java.io.*, java.nio.file.*, java.util.UUID" %>
<%@ page import="java.net.URL, java.net.HttpURLConnection, java.net.URI" %>
<%@ include file="../db.jsp" %>

<%!
    public static String escapeHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#x27;");
    }

    // SSRF 방지: 네이버, 구글 도메인만 허용
    public static boolean isAllowedUrl(String url) {
        try {
            URI uri = new URI(url);
            String host = uri.getHost();
            if (host == null) return false;

            String[] whitelist = {"naver.com", "google.com"};
            for (String allowed : whitelist) {
                if (host.equalsIgnoreCase(allowed) || host.endsWith("." + allowed)) {
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            return false;
        }
    }
%>

<%
    String username = (String) session.getAttribute("username");
    Integer userIdxObj = (Integer) session.getAttribute("idx");

    if (username == null || userIdxObj == null) {
%>
<script>
    alert('로그인 후 사용 가능합니다.');
    location.href = '../passlogic/login.jsp';
</script>
<%
        return;
    }

    int userIdx = userIdxObj;

    // [CSRF 토큰 발급] 세션에 없으면 한 번만 생성
    String csrf_token = (String) session.getAttribute("csrf_token");
    if (csrf_token == null) {
        csrf_token = UUID.randomUUID().toString().replace("-", "");
        session.setAttribute("csrf_token", csrf_token);
    }

    String imgUrl = request.getParameter("img_url");
    String previewHtml = "";
    if (imgUrl != null && !imgUrl.isEmpty()) {
        if (imgUrl.contains("<" + "%") || imgUrl.contains("%" + ">")) {
            previewHtml = "<span style='color:red;'>JSP 코드 실행은 허용되지 않습니다.</span>";
        } else {
            if (!isAllowedUrl(imgUrl)) {
                previewHtml = "<span style='color:red;'>허용되지 않은 도메인에 대한 접근은 차단됩니다.</span>";
            } else {
                try {
                    URL u = new URL(imgUrl);
                    HttpURLConnection conn = (HttpURLConnection) u.openConnection();
                    conn.setConnectTimeout(3000);
                    conn.setReadTimeout(3000);
                    conn.setRequestMethod("GET");
                    conn.connect();
                    String contentType = conn.getContentType();

                    if (contentType != null && contentType.startsWith("image/")) {
                        previewHtml = "<img src='" + escapeHtml(imgUrl) + "' style='max-width:300px;border:2px solid #aaa;'>";
                    } else {
                        BufferedReader in = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                        StringBuilder sb = new StringBuilder();
                        String inputLine;
                        int maxLen = 4096;
                        int totalLen = 0;
                        while ((inputLine = in.readLine()) != null && totalLen < maxLen) {
                            sb.append(escapeHtml(inputLine)).append("\n");
                            totalLen += inputLine.length();
                        }
                        in.close();
                        previewHtml = "<pre style='background:#222;color:#eaffef;padding:12px;border-radius:7px;max-width:600px;max-height:180px;overflow:auto;'>" +
                                sb.toString() + "</pre>";
                    }
                } catch (Exception e) {
                    previewHtml = "<span style='color:red'>요청 실패: " + escapeHtml(e.getMessage()) + "</span>";
                }
            }
        }
    }

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        // [CSRF 토큰 검증]
        String reqToken = request.getParameter("csrf_token");
        String sessToken = (String) session.getAttribute("csrf_token");
        if (reqToken == null || !reqToken.equals(sessToken)) {
%>
<script>
    alert('잘못된 접근입니다.(CSRF 차단)');
    history.back();
</script>
<%
            return;
        }

        String title = request.getParameter("title");
        String content = request.getParameter("content");
        String secret = request.getParameter("secret") != null ? "1" : "0";
        String boardFileOriginalName = "";

        Part filePart = null;
        InputStream fileInput = null;
        try { filePart = request.getPart("uploaded_file"); } catch (Exception e) {}

        if (filePart != null && filePart.getSize() > 0) {
            boardFileOriginalName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();
            String fileExt = boardFileOriginalName.substring(boardFileOriginalName.lastIndexOf('.') + 1).toLowerCase();
            String mimeType = filePart.getContentType();

            boolean isAllowed = false;
            if ((mimeType.startsWith("image/") && fileExt.matches("jpg|jpeg|png|gif|bmp")) ||
                (fileExt.equals("xlsx") && mimeType.equals("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")) ||
                (fileExt.equals("hwp") && mimeType.equals("application/x-hwp"))) {
                isAllowed = true;
            }

            if (!isAllowed) {
%>
<script>
    alert('허용되지 않은 파일 형식입니다. 이미지, 엑셀(xlsx), 한글(hwp) 파일만 업로드 가능합니다.');
    history.back();
</script>
<%
                return;
            }

            fileInput = filePart.getInputStream();
        }

        String insertSql = "INSERT INTO board_table (board_title, board_content, user_idx, board_file_original_name, board_secret, board_file_blob) VALUES (?, ?, ?, ?, ?, ?)";
        try {
            PreparedStatement pstmt = db_conn.prepareStatement(insertSql);
            pstmt.setString(1, title);
            pstmt.setString(2, content);
            pstmt.setInt(3, userIdx);
            pstmt.setString(4, boardFileOriginalName);
            pstmt.setInt(5, Integer.parseInt(secret));
            if (fileInput != null) {
                pstmt.setBlob(6, fileInput);
            } else {
                pstmt.setNull(6, java.sql.Types.BLOB);
            }
            pstmt.executeUpdate();
            pstmt.close();
%>
<script>
    alert('작성 완료되었습니다!');
    location.href = '../index.jsp';
</script>
<%
            return;
        } catch (Exception e) {
            out.println("DB 오류: " + escapeHtml(e.getMessage()));
        }
    }
%>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Sharks - 게시글 작성</title>
    <link rel="stylesheet" href="../style.css">
    <link rel="icon" href="../img/sharks2.jpg" type="image/jpeg">
</head>
<body>
<jsp:include page="../nav.jsp" />
<div class="write">
    <h1>글을 작성하세요.</h1>
    <hr/>
    <table class="writeTable">
        <tr>
            <th style="width:110px;">미리보기</th>
            <td>
                <form method="GET" action="write.jsp" style="margin-bottom:0; display:flex; gap:8px; align-items:center;">
                    <input type="text" name="img_url" placeholder="http://example.com/test.png"
                           style="flex:1; min-width:220px; padding:10px; border-radius:8px; border:1px solid #b5dbe7; font-size:1em;"
                           value="<%= escapeHtml(request.getParameter("img_url") != null ? request.getParameter("img_url") : "") %>">
                    <button type="submit"
                            style="padding:8px 18px; border-radius:8px; background:#aae0fa; color:#232f3e; border:none; font-weight:600; font-size:1em; cursor:pointer;">
                        미리보기
                    </button>
                </form>
                <div style="margin-top:12px;">
                    <%= previewHtml %>
                </div>
            </td>
        </tr>
    </table>
    <form method="POST" action="write.jsp" enctype="multipart/form-data">
        <input type="hidden" name="csrf_token" value="<%= csrf_token %>">
        <table class="writeTable">
            <tr>
                <th width="50">제목</th>
                <td><input type="text" name="title" placeholder="제목을 입력하세요." required></td>
            </tr>
            <tr>
                <th>내용</th>
                <td><textarea name="content" rows="5" cols="40" placeholder="내용을 입력하세요." required></textarea></td>
            </tr>
            <tr>
                <th>파일 업로드</th>
                <td><input type="file" name="uploaded_file"></td>
            </tr>
            <tr>
                <th>비밀글</th>
                <td>
                    <label>
                        <input type="checkbox" name="secret" value="1"> 비밀글
                    </label>
                </td>
            </tr>
        </table>
        <ul>
            <li><input class="button" type="submit" value="작성 완료"></li>
            <li><button type="button" onclick="location.href='../index.jsp'">취소</button></li>
        </ul>
    </form>
</div>
<script src="../js/modal.js"></script>
</body>
</html>
