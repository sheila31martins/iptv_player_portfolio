import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() {
  runApp(const IPTVPlayerApp());
}

class IPTVPlayerApp extends StatelessWidget {
  const IPTVPlayerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV Player'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.live_tv, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Bem-vindo ao IPTV Player!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Adicione sua lista M3U para começar a assistir.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddM3UScreen()),
                );
              },
              child: const Text('Adicionar Lista M3U'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddM3UScreen extends StatefulWidget {
  const AddM3UScreen({Key? key}) : super(key: key);

  @override
  State<AddM3UScreen> createState() => _AddM3UScreenState();
}

class _AddM3UScreenState extends State<AddM3UScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _mensagemErro;
  bool _carregando = false;

  Future<void> _buscarEExibirCanais(String url) async {
    setState(() {
      _carregando = true;
    });
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final canais = _parseM3U(response.body);
        if (canais.isEmpty) {
          setState(() {
            _mensagemErro = 'Nenhum canal encontrado na lista.';
            _carregando = false;
          });
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ListaCanaisScreen(canais: canais),
          ),
        );
      } else {
        setState(() {
          _mensagemErro = 'Erro ao baixar a lista (HTTP ${response.statusCode})';
          _carregando = false;
        });
      }
    } catch (e) {
      setState(() {
        _mensagemErro = 'Erro ao acessar a URL: $e';
        _carregando = false;
      });
    }
  }

  List<Map<String, String>> _parseM3U(String conteudo) {
    final linhas = LineSplitter.split(conteudo).toList();
    final canais = <Map<String, String>>[];
    String? nome;
    for (var linha in linhas) {
      if (linha.startsWith('#EXTINF')) {
        final nomeMatch = RegExp(r',(.+)$').firstMatch(linha);
        nome = nomeMatch != null ? nomeMatch.group(1) : null;
      } else if (nome != null && linha.trim().isNotEmpty && !linha.startsWith('#')) {
        canais.add({'nome': nome, 'url': linha.trim()});
        nome = null;
      }
    }
    return canais;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Lista M3U'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cole a URL da sua lista M3U:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'https://exemplo.com/sualista.m3u',
                errorText: _mensagemErro,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            _carregando
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _mensagemErro = null;
                      });
                      final url = _controller.text.trim();
                      if (url.isEmpty || !url.startsWith('http')) {
                        setState(() {
                          _mensagemErro = 'Informe uma URL válida.';
                        });
                        return;
                      }
                      _buscarEExibirCanais(url);
                    },
                    child: const Text('Salvar'),
                  ),
          ],
        ),
      ),
    );
  }
}

class ListaCanaisScreen extends StatelessWidget {
  final List<Map<String, String>> canais;
  const ListaCanaisScreen({Key? key, required this.canais}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canais IPTV')),
      body: ListView.separated(
        itemCount: canais.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final canal = canais[index];
          return ListTile(
            leading: const Icon(Icons.tv),
            title: Text(canal['nome'] ?? 'Sem nome'),
            subtitle: Text(canal['url'] ?? ''),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    nome: canal['nome'] ?? 'Sem nome',
                    url: canal['url'] ?? '',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String nome;
  final String url;
  const VideoPlayerScreen({Key? key, required this.nome, required this.url}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _inicializado = false;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {
          _inicializado = true;
        });
        _controller.play();
      }).catchError((e) {
        setState(() {
          _erro = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.nome)),
      body: Center(
        child: _erro
            ? const Text('Erro ao carregar o vídeo.')
            : _inicializado
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(),
      ),
      floatingActionButton: _inicializado && !_erro
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}

